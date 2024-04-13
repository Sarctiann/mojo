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
"""Implements the Reference type.

You can import these APIs from the `memory` package. For example:

```mojo
from memory.reference import Reference
```
"""

# ===----------------------------------------------------------------------===#
# AddressSpace
# ===----------------------------------------------------------------------===#


@value
@register_passable("trivial")
struct _GPUAddressSpace(EqualityComparable):
    var _value: Int

    # See https://docs.nvidia.com/cuda/nvvm-ir-spec/#address-space
    alias GENERIC = AddressSpace(0)
    """Generic address space."""
    alias GLOBAL = AddressSpace(1)
    """Global address space."""
    alias CONSTANT = AddressSpace(2)
    """Constant address space."""
    alias SHARED = AddressSpace(3)
    """Shared address space."""
    alias PARAM = AddressSpace(4)
    """Param address space."""
    alias LOCAL = AddressSpace(5)
    """Local address space."""

    @always_inline("nodebug")
    fn __init__(value: Int) -> Self:
        return Self {_value: value}

    @always_inline("nodebug")
    fn value(self) -> Int:
        """The integral value of the address space.

        Returns:
          The integral value of the address space.
        """
        return self._value

    @always_inline("nodebug")
    fn __int__(self) -> Int:
        """The integral value of the address space.

        Returns:
          The integral value of the address space.
        """
        return self._value

    @always_inline("nodebug")
    fn __eq__(self, other: Self) -> Bool:
        """The True if the two address spaces are equal and False otherwise.

        Returns:
          True if the two address spaces are equal and False otherwise.
        """
        return self.value() == other.value()

    @always_inline("nodebug")
    fn __eq__(self, other: AddressSpace) -> Bool:
        """The True if the two address spaces are equal and False otherwise.

        Returns:
          True if the two address spaces are equal and False otherwise.
        """
        return self.value() == other.value()

    @always_inline("nodebug")
    fn __ne__(self, other: Self) -> Bool:
        """True if the two address spaces are inequal and False otherwise.

        Args:
          other: The other address space value.

        Returns:
          True if the two address spaces are inequal and False otherwise.
        """
        return not self == other

    @always_inline("nodebug")
    fn __ne__(self, other: AddressSpace) -> Bool:
        """True if the two address spaces are inequal and False otherwise.

        Args:
          other: The other address space value.

        Returns:
          True if the two address spaces are inequal and False otherwise.
        """
        return not self == other


@value
@register_passable("trivial")
struct AddressSpace(EqualityComparable):
    """Address space of the pointer."""

    var _value: Int

    alias GENERIC = AddressSpace(0)
    """Generic address space."""

    @always_inline("nodebug")
    fn __init__(value: Int) -> Self:
        """Initializes the address space from the underlying integeral value.

        Args:
          value: The address space value.

        Returns:
          The address space.
        """
        return Self {_value: value}

    @always_inline("nodebug")
    fn __init__(value: _GPUAddressSpace) -> Self:
        """Initializes the address space from the underlying integeral value.

        Args:
          value: The address space value.

        Returns:
          The address space.
        """
        return Self {_value: int(value)}

    @always_inline("nodebug")
    fn value(self) -> Int:
        """The integral value of the address space.

        Returns:
          The integral value of the address space.
        """
        return self._value

    @always_inline("nodebug")
    fn __int__(self) -> Int:
        """The integral value of the address space.

        Returns:
          The integral value of the address space.
        """
        return self._value

    @always_inline("nodebug")
    fn __eq__(self, other: Self) -> Bool:
        """True if the two address spaces are equal and False otherwise.

        Args:
          other: The other address space value.

        Returns:
          True if the two address spaces are equal and False otherwise.
        """
        return self.value() == other.value()

    @always_inline("nodebug")
    fn __ne__(self, other: Self) -> Bool:
        """True if the two address spaces are inequal and False otherwise.

        Args:
          other: The other address space value.

        Returns:
          True if the two address spaces are inequal and False otherwise.
        """
        return not self == other


# ===----------------------------------------------------------------------===#
# Reference
# ===----------------------------------------------------------------------===#


# Helper to build !lit.ref types.
# TODO: parametric aliases would be nice.
struct _LITRef[
    element_type: AnyType,
    elt_is_mutable: __mlir_type.i1,
    lifetime: AnyLifetime[elt_is_mutable].type,
    address_space: AddressSpace = AddressSpace.GENERIC,
]:
    alias type = __mlir_type[
        `!lit.ref<`,
        element_type,
        `, `,
        lifetime,
        `, `,
        address_space._value.value,
        `>`,
    ]


@value
@register_passable("trivial")
struct Reference[
    type: AnyType,
    is_mutable: __mlir_type.i1,
    lifetime: AnyLifetime[is_mutable].type,
    address_space: AddressSpace = AddressSpace.GENERIC,
]:
    """Defines a non-nullable safe reference.

    Parameters:
        type: Type of the underlying data.
        is_mutable: Whether the referenced data may be mutated through this.
        lifetime: The lifetime of the reference.
        address_space: The address space of the referenced data.
    """

    alias mlir_ref_type = _LITRef[
        type, is_mutable, lifetime, address_space
    ].type

    var value: Self.mlir_ref_type
    """The underlying MLIR reference."""

    @always_inline("nodebug")
    fn __init__(inout self, value: Self.mlir_ref_type):
        """Constructs a Reference from the MLIR reference.

        Args:
            value: The MLIR reference.
        """
        self.value = value

    @always_inline("nodebug")
    fn __refitem__(self) -> Self.mlir_ref_type:
        """Enable subscript syntax `ref[]` to access the element.

        Returns:
            The MLIR reference for the Mojo compiler to use.
        """
        return self.value

    @always_inline("nodebug")
    fn __mlir_ref__(self) -> Self.mlir_ref_type:
        """Enable the Mojo compiler to see into `Reference`.

        Returns:
            The MLIR reference for the Mojo compiler to use.
        """
        return self.value

    # FIXME: This should be on Pointer, but can't due to AnyRefType vs AnyType
    # disagreement.  Use UnsafePointer instead!
    @always_inline("nodebug")
    fn get_legacy_pointer(self) -> Pointer[type, address_space]:
        """Constructs a Pointer from a safe reference.

        Returns:
            Constructed Pointer object.
        """
        # Work around AnyRegType vs AnyType.
        return __mlir_op.`pop.pointer.bitcast`[
            _type = Pointer[type, address_space].pointer_type
        ](UnsafePointer(self).value)

    @always_inline("nodebug")
    fn get_unsafe_pointer(self) -> UnsafePointer[type, address_space]:
        """Constructs a UnsafePointer from a safe reference.

        Returns:
            Constructed UnsafePointer object.
        """
        return UnsafePointer(self).value

    @always_inline("nodebug")
    fn bitcast_element[
        new_element_type: AnyType
    ](self) -> Reference[new_element_type, is_mutable, lifetime, address_space]:
        """Cast the reference to one of another element type, but the same
        lifetime, mutability, and address space.

        Parameters:
            new_element_type: The result type.

        Returns:
            The new reference.
        """
        # We don't have a `lit.ref.cast`` operation, so convert through a KGEN
        # pointer.
        return UnsafePointer(self).bitcast_element[new_element_type]()[]

    @always_inline
    fn address_space_cast[
        new_address_space: AddressSpace
    ](self) -> Reference[type, is_mutable, lifetime, new_address_space]:
        """Cast the reference to one of another address space, but the same
        element type, lifetime, and mutability.

        Parameters:
            new_address_space: The address space of the result.

        Returns:
            The new reference.
        """
        # We don't have a `lit.ref.cast`` operation, so convert through a KGEN
        # pointer.
        return UnsafePointer(self).address_space_cast[new_address_space]()[]