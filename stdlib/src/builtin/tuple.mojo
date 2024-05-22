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
"""Implements the Tuple type.

These are Mojo built-ins, so you don't need to import them.
"""

from utils._visualizers import lldb_formatter_wrapping_type

from memory.unsafe_pointer import (
    initialize_pointee_move,
    initialize_pointee_copy,
    move_pointee,
)

from sys.intrinsics import _type_is_eq

# ===----------------------------------------------------------------------===#
# Tuple
# ===----------------------------------------------------------------------===#


@lldb_formatter_wrapping_type
struct Tuple[*element_types: Movable](Sized, Movable):
    """The type of a literal tuple expression.

    A tuple consists of zero or more values, separated by commas.

    Parameters:
        element_types: The elements type.
    """

    alias _mlir_type = __mlir_type[
        `!kgen.pack<:!kgen.variadic<`,
        Movable,
        `> `,
        +element_types,
        `>`,
    ]

    var storage: Self._mlir_type
    """The underlying storage for the tuple."""

    @always_inline("nodebug")
    fn __init__(inout self, owned *args: *element_types):
        """Construct the tuple.

        Args:
            args: Initial values.
        """
        self = Self(storage=args^)

    @always_inline("nodebug")
    fn __init__(
        inout self,
        *,
        owned storage: VariadicPack[_, _, Movable, element_types],
    ):
        """Construct the tuple from a low-level internal representation.

        Args:
            storage: The variadic pack storage to construct from.
        """

        # Mark 'self.storage' as being initialized so we can work on it.
        __mlir_op.`lit.ownership.mark_initialized`(
            __get_mvalue_as_litref(self.storage)
        )

        @parameter
        fn initialize_elt[idx: Int]():
            move_pointee(
                dst=UnsafePointer(self[idx]),
                src=UnsafePointer(storage[idx]),
            )

        # Move each element into the tuple storage.
        unroll[initialize_elt, Self.__len__()]()

        # Mark the elements as already destroyed.
        storage._is_owned = False

    fn __del__(owned self):
        """Destructor that destroys all of the elements."""

        # Run the destructor on each member, the destructor of !kgen.pack is
        # trivial and won't do anything.
        @parameter
        fn destroy_elt[idx: Int]():
            destroy_pointee(UnsafePointer(self[idx]))

        unroll[destroy_elt, Self.__len__()]()

    @always_inline("nodebug")
    fn __moveinit__(inout self, owned existing: Self):
        """Move construct the tuple.

        Args:
            existing: The value to move from.
        """
        # Mark 'storage' as being initialized so we can work on it.
        __mlir_op.`lit.ownership.mark_initialized`(
            __get_mvalue_as_litref(self.storage)
        )

        @parameter
        fn initialize_elt[idx: Int]():
            var existing_elt_ptr = UnsafePointer(existing[idx]).address
            move_pointee(
                src=UnsafePointer(existing[idx]), dst=UnsafePointer(self[idx])
            )

        unroll[initialize_elt, Self.__len__()]()

    @always_inline
    @staticmethod
    fn __len__() -> Int:
        """Return the number of elements in the tuple.

        Returns:
            The tuple length.
        """

        @parameter
        fn variadic_size(
            x: __mlir_type[`!kgen.variadic<`, Movable, `>`]
        ) -> Int:
            return __mlir_op.`pop.variadic.size`(x)

        alias result = variadic_size(element_types)
        return result

    @always_inline("nodebug")
    fn __len__(self) -> Int:
        """Get the number of elements in the tuple.

        Returns:
            The tuple length.
        """
        return Self.__len__()

    @always_inline("nodebug")
    fn __refitem__[
        idx: Int
    ](self: Reference[Self, _, _]) -> Reference[
        element_types[idx.value], self.is_mutable, self.lifetime
    ]:
        # Return a reference to an element at the specified index, propagating
        # mutability of self.
        var storage_kgen_ptr = UnsafePointer.address_of(self[].storage).address

        # KGenPointer to the element.
        var elt_kgen_ptr = __mlir_op.`kgen.pack.gep`[index = idx.value](
            storage_kgen_ptr
        )
        # Use an immortal mut reference, which converts to self's lifetime.
        return UnsafePointer(elt_kgen_ptr)[]

    # TODO(#38268): Remove this method when references and parameter expressions
    # cooperate better.  We can't handle the use in test_simd without this.
    @always_inline("nodebug")
    fn get[i: Int, T: Movable](self) -> T:
        """Get a tuple element and rebind to the specified type.

        Parameters:
            i: The element index.
            T: The element type.

        Returns:
            The tuple element at the requested index.
        """
        return rebind[T](self[i])

    @always_inline("nodebug")
    fn __contains__[
        T: ComparableCollectionElement
    ](self: Self, value: T) -> Bool:
        """Verify if a given value is present in the tuple.

        ```mojo
        var x = Tuple(1,2,True)
        if 1 in x: print("x contains 1")
        ```

        Args:
            value: The value to find.

        Parameters:
            T: The type of the value argument. Must implement the
              trait `ComparableCollectionElement`.

        Returns:
            True if the value is contained in the tuple, False otherwise.
        """

        @parameter
        fn T_in_ts() -> Bool:
            var res = False

            @parameter
            for i in range(len(VariadicList(element_types))):

                @parameter
                if _type_is_eq[element_types[i], T]():
                    res |= True
            return res

        @parameter
        if not T_in_ts():
            return False

        @parameter
        for i in range(len(VariadicList(element_types))):

            @parameter
            if _type_is_eq[T, element_types[i]]():
                var tmp_ref = self.__refitem__[i]()
                var tmp = rebind[
                    Reference[
                        T,
                        tmp_ref.is_mutable,
                        tmp_ref.lifetime,
                        tmp_ref.address_space,
                    ]
                ](tmp_ref)
                if tmp[].__eq__(value):
                    return True

        return False
