# ===----------------------------------------------------------------------=== #
# Copyright (c) 2024, Modular Inc. All rights reserved.
#
# Licensed under the Apache License v2.0 with LLVM Exceptions:
# https://llvm.org/LICENSE.txt
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
# ===----------------------------------------------------------------------=== #
"""Implements the Atomic class.

You can import these APIs from the `os` package. For example:

```mojo
from os.atomic import Atomic
```
"""

from builtin.dtype import _integral_type_of
from memory.unsafe import Pointer, bitcast


struct Atomic[type: DType]:
    """Represents a value with atomic operations.

    The class provides atomic `add` and `sub` methods for mutating the value.

    Parameters:
        type: DType of the value.
    """

    var value: Scalar[type]
    """The atomic value.

    This is the underlying value of the atomic. Access to the value can only
    occur through atomic primitive operations.
    """

    @always_inline
    fn __init__(inout self, value: Scalar[type]):
        """Constructs a new atomic value.

        Args:
            value: Initial value represented as `Scalar[type]` type.
        """
        self.value = value

    @always_inline
    fn __init__(inout self, value: Int):
        """Constructs a new atomic value.

        Args:
            value: Initial value represented as `mlir.index` type.
        """
        self.__init__(Scalar[type](value))

    @staticmethod
    @always_inline
    fn _fetch_add(
        ptr: Pointer[Scalar[type]], rhs: Scalar[type]
    ) -> Scalar[type]:
        """Performs atomic in-place add.

        Atomically replaces the current value with the result of arithmetic
        addition of the value and arg. That is, it performs atomic
        post-increment. The operation is a read-modify-write operation. Memory
        is affected according to the value of order which is sequentially
        consistent.

        Args:
            ptr: The source pointer.
            rhs: Value to add.

        Returns:
            The original value before addition.
        """
        return __mlir_op.`pop.atomic.rmw`[
            bin_op = __mlir_attr.`#pop<bin_op add>`,
            ordering = __mlir_attr.`#pop<atomic_ordering seq_cst>`,
            _type = __mlir_type[`!pop.scalar<`, type.value, `>`],
        ](
            bitcast[__mlir_type[`!pop.scalar<`, type.value, `>`]](ptr).address,
            rhs.value,
        )

    @always_inline
    fn fetch_add(inout self, rhs: Scalar[type]) -> Scalar[type]:
        """Performs atomic in-place add.

        Atomically replaces the current value with the result of arithmetic
        addition of the value and arg. That is, it performs atomic
        post-increment. The operation is a read-modify-write operation. Memory
        is affected according to the value of order which is sequentially
        consistent.

        Args:
            rhs: Value to add.

        Returns:
            The original value before addition.
        """
        var value_addr = Pointer.address_of(self.value)
        return Self._fetch_add(value_addr, rhs)

    @always_inline
    fn __iadd__(inout self, rhs: Scalar[type]):
        """Performs atomic in-place add.

        Atomically replaces the current value with the result of arithmetic
        addition of the value and arg. That is, it performs atomic
        post-increment. The operation is a read-modify-write operation. Memory
        is affected according to the value of order which is sequentially
        consistent.

        Args:
            rhs: Value to add.
        """
        _ = self.fetch_add(rhs)

    @always_inline
    fn fetch_sub(inout self, rhs: Scalar[type]) -> Scalar[type]:
        """Performs atomic in-place sub.

        Atomically replaces the current value with the result of arithmetic
        subtraction of the value and arg. That is, it performs atomic
        post-decrement. The operation is a read-modify-write operation. Memory
        is affected according to the value of order which is sequentially
        consistent.

        Args:
            rhs: Value to subtract.

        Returns:
            The original value before subtraction.
        """
        var value_addr = Pointer.address_of(self.value.value)
        return __mlir_op.`pop.atomic.rmw`[
            bin_op = __mlir_attr.`#pop<bin_op sub>`,
            ordering = __mlir_attr.`#pop<atomic_ordering seq_cst>`,
            _type = __mlir_type[`!pop.scalar<`, type.value, `>`],
        ](value_addr.address, rhs.value)

    @always_inline
    fn __isub__(inout self, rhs: Scalar[type]):
        """Performs atomic in-place sub.

        Atomically replaces the current value with the result of arithmetic
        subtraction of the value and arg. That is, it performs atomic
        post-decrement. The operation is a read-modify-write operation. Memory
        is affected according to the value of order which is sequentially
        consistent.

        Args:
            rhs: Value to subtract.
        """
        _ = self.fetch_sub(rhs)

    @always_inline
    fn _compare_exchange_weak(
        inout self, expected: Scalar[type], desired: Scalar[type]
    ) -> Bool:
        constrained[
            type.is_integral() or type.is_floating_point(),
            "the input type must be arithmetic",
        ]()

        @parameter
        if type.is_integral():
            var value_addr = Pointer.address_of(self.value.value)
            var cmpxchg_res = __mlir_op.`pop.atomic.cmpxchg`[
                bin_op = __mlir_attr.`#pop<bin_op sub>`,
                failure_ordering = __mlir_attr.`#pop<atomic_ordering seq_cst>`,
                success_ordering = __mlir_attr.`#pop<atomic_ordering seq_cst>`,
            ](
                value_addr.address,
                expected.value,
                desired.value,
            )
            return __mlir_op.`kgen.struct.extract`[
                index = __mlir_attr.`1:index`
            ](cmpxchg_res)

        # For the floating point case, we need to bitcast the floating point
        # values to their integral representation and perform the atomic
        # operation on that.

        alias integral_type = _integral_type_of[type]()
        var value_integral_addr = Pointer.address_of(self.value.value).bitcast[
            __mlir_type[`!pop.scalar<`, integral_type.value, `>`]
        ]()
        var expected_integral = bitcast[integral_type](expected)
        var desired_integral = bitcast[integral_type](desired)

        var cmpxchg_res = __mlir_op.`pop.atomic.cmpxchg`[
            bin_op = __mlir_attr.`#pop<bin_op sub>`,
            failure_ordering = __mlir_attr.`#pop<atomic_ordering seq_cst>`,
            success_ordering = __mlir_attr.`#pop<atomic_ordering seq_cst>`,
        ](
            value_integral_addr.address,
            expected_integral.value,
            desired_integral.value,
        )
        return __mlir_op.`kgen.struct.extract`[index = __mlir_attr.`1:index`](
            cmpxchg_res
        )

    @always_inline
    fn max(inout self, rhs: Scalar[type]):
        """Performs atomic in-place max.

        Atomically replaces the current value with the result of max of the
        value and arg. The operation is a read-modify-write operation perform
        according to sequential consistency semantics.

        Constraints:
            The input type must be either integral or floating-point type.


        Args:
            rhs: Value to max.
        """
        constrained[
            type.is_integral() or type.is_floating_point(),
            "the input type must be arithmetic",
        ]()

        var value_addr = Pointer.address_of(self.value.value)
        _ = __mlir_op.`pop.atomic.rmw`[
            bin_op = __mlir_attr.`#pop<bin_op max>`,
            ordering = __mlir_attr.`#pop<atomic_ordering seq_cst>`,
            _type = __mlir_type[`!pop.scalar<`, type.value, `>`],
        ](value_addr.address, rhs.value)

    @always_inline
    fn min(inout self, rhs: Scalar[type]):
        """Performs atomic in-place min.

        Atomically replaces the current value with the result of min of the
        value and arg. The operation is a read-modify-write operation. The
        operation is a read-modify-write operation perform according to
        sequential consistency semantics.

        Constraints:
            The input type must be either integral or floating-point type.

        Args:
            rhs: Value to min.
        """

        constrained[
            type.is_integral() or type.is_floating_point(),
            "the input type must be arithmetic",
        ]()

        var value_addr = Pointer.address_of(self.value.value)
        _ = __mlir_op.`pop.atomic.rmw`[
            bin_op = __mlir_attr.`#pop<bin_op min>`,
            ordering = __mlir_attr.`#pop<atomic_ordering seq_cst>`,
            _type = __mlir_type[`!pop.scalar<`, type.value, `>`],
        ](value_addr.address, rhs.value)
