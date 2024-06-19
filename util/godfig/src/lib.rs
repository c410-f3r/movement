pub mod backend;

#[macro_export]
macro_rules! env_default {
	// Case with default value
	($name:ident, $env:expr, $ty:ty, $default:expr) => {
		pub fn $name() -> $ty {
			std::env::var($env).ok().and_then(|v| v.parse().ok()).unwrap_or($default)
		}
	};
	// Case without default value
	($name:ident, $env:expr, $ty:ty) => {
		pub fn $name() -> Option<$ty> {
			std::env::var($env).ok().and_then(|v| v.parse().ok())
		}
	};
}

#[cfg(test)]
mod test {

	#[test]
	fn test_env_default_with_env() {
		std::env::set_var("TEST_ENV_DEFAULT", "42");

		// without default value
		env_default!(my_env, "TEST_ENV_DEFAULT", i32);
		let result = my_env();
		assert_eq!(result, Some(42));

		// with default value
		env_default!(my_env_with_default, "TEST_ENV_DEFAULT", i32, 0);
		let result = my_env_with_default();
		assert_eq!(result, 42);
	}

	#[test]
	fn test_env_default_without_env() {
		std::env::remove_var("TEST_ENV_DEFAULT");

		// without default value
		env_default!(my_env, "TEST_ENV_DEFAULT", i32);
		let result = my_env();
		assert_eq!(result, None);

		// with default value
		env_default!(my_env_with_default, "TEST_ENV_DEFAULT", i32, 0);
		let result = my_env_with_default();
		assert_eq!(result, 0);
	}
}
