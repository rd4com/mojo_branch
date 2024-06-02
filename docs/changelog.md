# Mojo unreleased changelog

This is a list of UNRELEASED changes for the Mojo language and tools.

When we cut a release, these notes move to `changelog-released.md` and that's
what we publish.

[//]: # Here's the template to use when starting a new batch of notes:
[//]: ## UNRELEASED
[//]: ### ⭐️ New
[//]: ### 🦋 Changed
[//]: ### ❌ Removed
[//]: ### 🛠️ Fixed

## UNRELEASED

### ⭐️ New

- Added new `ExplicitlyCopyable` trait, to mark types that can be copied
  explicitly, but which might not be implicitly copyable.

  This supports work to transition the standard library collection types away
  from implicit copyability, which can lead to unintended expensive copies.

- `Dict` now supports `popitem`, which removes and returns the last item in the `Dict`.
([PR #2701](https://github.com/modularml/mojo/pull/2701)
by [@jayzhan211](https://github.com/jayzhan211))

- Added `String.unsafe_cstr_ptr(self)` that returns an `UnsafePointer[C_char]`
  for convenient interoperability with C APIs.

- Added `C_char` type alias in `sys.ffi`.

- Added one `format` method overload to both `StringLiteral` and `String`:

  It builds a new `String` with a format template like in `🐍`
  
  ⚠️ Does not work in the parameter domain (`alias`) yet

  For example:
  
  ```mojo
  var x = "{0} %2 == {1} {mojo} {number}".format(
      1024, True, mojo="❤️‍🔥", number=str(1.125)
  )
  print(x) #1024 %2 == True ❤️‍🔥 1.125
  ```

### 🦋 Changed

- Continued transition to `UnsafePointer` and unsigned byte type for strings:
  - `String.unsafe_ptr()` now returns an `UnsafePointer[UInt8]`
    (was `UnsafePointer[Int8]`)

### ❌ Removed

- Removed `String.unsafe_uint8_ptr()`. `String.unsafe_ptr()` now returns the
  same thing.

- Removed `UnsafePointer.offset(offset:Int)`.

### 🛠️ Fixed
