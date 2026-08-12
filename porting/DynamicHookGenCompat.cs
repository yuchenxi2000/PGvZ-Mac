using System;
using System.Collections.Generic;
using System.Dynamic;
using System.Linq;
using System.Reflection;
using MonoMod.Cil;

namespace MonoMod.RuntimeDetour;

// RuntimeDetour 25.x supports macOS arm64 but removed the old DynamicHookGen
// facade used by the game and its Python API. This compatibility facade keeps
// the public dynamic syntax while delegating actual hooks to the current API.
public sealed class DynamicHookGen : DynamicObject
{
	private sealed class HookRegistration
	{
		public MethodBase Method;

		public Delegate Delegate;

		public bool IsIl;

		public IDisposable Detour;
	}

	private static readonly object sHookLock = new object();

	private static readonly List<HookRegistration> sHooks = new List<HookRegistration>();

	public enum HookType
	{
		On,
		IL,
		OnOrIL
	}

	private readonly Type mType;

	private readonly string[] mPath;

	private readonly HookType mHookType;

	public static dynamic On { get; } = new DynamicHookGen(null, Array.Empty<string>(), HookType.On);

	public static dynamic OnOrIL { get; } = new DynamicHookGen(null, Array.Empty<string>(), HookType.OnOrIL);

	public static dynamic IL { get; } = new DynamicHookGen(null, Array.Empty<string>(), HookType.IL);

	public DynamicHookGen(Type type, HookType hookType = HookType.OnOrIL)
		: this(type, Array.Empty<string>(), hookType)
	{
	}

	private DynamicHookGen(Type type, string[] path, HookType hookType)
	{
		mType = type;
		mPath = path;
		mHookType = hookType;
	}

	public override bool TryGetMember(GetMemberBinder binder, out object result)
	{
		string[] path = new string[mPath.Length + 1];
		mPath.CopyTo(path, 0);
		path[^1] = binder.Name;
		result = new DynamicHookGen(mType, path, mHookType);
		return true;
	}

	public override bool TrySetMember(SetMemberBinder binder, object value)
	{
		// Compound dynamic assignment writes the endpoint returned by operator
		// + or - back to its parent. The operator already changed the hook.
		return true;
	}

	public static DynamicHookGen operator +(DynamicHookGen endpoint, Delegate hook)
	{
		endpoint.ChangeHook(hook, add: true);
		return endpoint;
	}

	public static DynamicHookGen operator -(DynamicHookGen endpoint, Delegate hook)
	{
		endpoint.ChangeHook(hook, add: false);
		return endpoint;
	}

	private void ChangeHook(Delegate hook, bool add)
	{
		MethodBase method = ResolveMethod(hook);
		bool useIl = mHookType == HookType.IL || (mHookType == HookType.OnOrIL && !HasOrigDelegate(hook));
		lock (sHookLock)
		{
			if (add)
			{
				IDisposable detour;
				if (useIl)
				{
					ILContext.Manipulator manipulator = (ILContext.Manipulator)Delegate.CreateDelegate(typeof(ILContext.Manipulator), hook.Target, hook.Method);
					detour = new ILHook(method, manipulator);
				}
				else
				{
					detour = new Hook(method, hook);
				}
				sHooks.Add(new HookRegistration
				{
					Method = method,
					Delegate = hook,
					IsIl = useIl,
					Detour = detour
				});
			}
			else
			{
				int index = sHooks.FindLastIndex(registration => registration.Method == method && registration.IsIl == useIl && registration.Delegate.Equals(hook));
				if (index >= 0)
				{
					sHooks[index].Detour.Dispose();
					sHooks.RemoveAt(index);
				}
			}
		}
	}

	private MethodBase ResolveMethod(Delegate hook)
	{
		if (mPath.Length == 0)
		{
			throw new MissingMethodException("A hook endpoint must include a method name.");
		}

		Type type = mType;
		string methodName;
		if (type != null)
		{
			methodName = mPath[^1];
		}
		else
		{
			if (mPath.Length < 2)
			{
				throw new MissingMethodException("A dynamic hook endpoint must include a type and method name.");
			}
			string typeName = string.Join(".", mPath[..^1]);
			type = AppDomain.CurrentDomain.GetAssemblies()
				.Select(assembly => assembly.GetType(typeName, throwOnError: false))
				.FirstOrDefault(candidate => candidate != null);
			if (type == null)
			{
				throw new TypeLoadException($"Cannot resolve hook type '{typeName}'.");
			}
			methodName = mPath[^1];
		}

		MethodBase method = type.GetMethods(BindingFlags.Public | BindingFlags.NonPublic | BindingFlags.Instance | BindingFlags.Static)
			.Where(candidate => candidate.Name == methodName)
			.FirstOrDefault(candidate => MatchesHook(candidate, hook));
		return method ?? throw new MissingMethodException(type.FullName, methodName);
	}

	private static bool HasOrigDelegate(Delegate hook)
	{
		ParameterInfo[] parameters = hook.GetType().GetMethod("Invoke").GetParameters();
		return parameters.Length > 0 && typeof(Delegate).IsAssignableFrom(parameters[0].ParameterType);
	}

	private static bool MatchesHook(MethodInfo method, Delegate hook)
	{
		MethodInfo hookInvoke = hook.GetType().GetMethod("Invoke");
		ParameterInfo[] hookParameters = hookInvoke.GetParameters();
		ParameterInfo[] methodParameters = method.GetParameters();
		int instanceOffset = method.IsStatic ? 0 : 1;
		int hookOffset = HasOrigDelegate(hook) ? 1 : 0;
		if (hookParameters.Length - hookOffset != methodParameters.Length + instanceOffset)
		{
			return false;
		}
		if (hookInvoke.ReturnType != method.ReturnType)
		{
			return false;
		}
		if (!method.IsStatic && hookParameters[hookOffset].ParameterType != method.DeclaringType)
		{
			return false;
		}
		for (int i = 0; i < methodParameters.Length; i++)
		{
			if (hookParameters[hookOffset + instanceOffset + i].ParameterType != methodParameters[i].ParameterType)
			{
				return false;
			}
		}
		return true;
	}
}
