# SO Processor Emulator

An Assembly program developed for the Operating System course at the University of Warsaw. It implements an x86-64 assembly function to emulate the operation of the SO processor, callable from C.

## Detailed description

### SO Processor Architecture

The SO processor has four 8-bit data registers named: `A`, `D`, `X`, `Y`; an 8-bit program counter `PC`; a single-bit carry/borrow flag `C` for arithmetic operations; and a single-bit `Z` flag, which is set when the result of an arithmetic or logical operation is zero, and cleared otherwise. At the start, all register values and flags are zero.

The SO processor uses 8-bit addressing, with separate address spaces for data and programs. The data memory holds 256 bytes, while the program memory holds 256 16-bit words.

All data and address operations are performed modulo 256. During instruction execution, the program counter is incremented by one to point to the next instruction unless a jump is performed, in which case an additional constant from the instruction code is added to the program counter. All jumps are relative.

A list of SO processor instructions is provided below.

The SO processor can be single-core or multi-core.

### Single-Core Version

Implement the following `x86-64` assembly function, callable from C:

```c
so_state_t so_emul(uint16_t const *code, uint8_t *data, size_t steps);
```

- The `code` parameter points to the program memory.
- The `data` parameter points to the data memory.
- The `steps` parameter indicates the number of steps (or instructions) the emulator should execute.
  
The function returns a structure instance representing the current processor state, including the values of its registers and flags. The processor state should be retained across successive calls to this function. The structure is defined as follows:

```c
typedef struct __attribute__((packed)) {
  uint8_t A, D, X, Y, PC;
  uint8_t unused; // Padding to make the structure 8 bytes.
  bool    C, Z;
} so_state_t;
```

### Multi-Core Version

Implement the following `x86-64` assembly function, callable from C, where the additional `core` parameter specifies the core number. Cores are numbered from 0 to `CORES - 1`, where `CORES` is a compile-time constant.

```c
so_state_t so_emul(uint16_t const *code, uint8_t *data, size_t steps, size_t core);
```

The function returns a structure instance representing the current state of the specified core. Each core has its own set of registers and flags. For each core, the `so_emul` function runs in a separate thread.

### Single-Core Processor Instructions

The term "code" below refers to the machine code, i.e., the binary representation of the instruction or instruction parameter. Instructions may have parameters labeled `arg1`, `arg2`, or `imm8`. The `imm8` parameter is an 8-bit constant. The `arg1` and `arg2` parameters can take the following forms:

- `A` – Value of the `A` register, code `0`
- `D` – Value of the `D` register, code `1`
- `X` – Value of the `X` register, code `2`
- `Y` – Value of the `Y` register, code `3`
- `[X]` – Value in data memory at the address in register `X`, code `4`
- `[Y]` – Value in data memory at the address in register `Y`, code `5`
- `[X + D]` – Value in data memory at the address equal to the sum of registers `X` and `D`, code `6`
- `[Y + D]` – Value in data memory at the address equal to the sum of registers `Y` and `D`, code `7`

### Instruction List

1. **MOV arg1, arg2**  
   **Code**: `0x0000 + 0x100 * arg1 + 0x0800 * arg2`  
   Copies the value of `arg2` to `arg1`. Does not modify flags.

2. **OR arg1, arg2**  
   **Code**: `0x0002 + 0x100 * arg1 + 0x0800 * arg2`  
   Performs a bitwise OR between `arg1` and `arg2`, storing the result in `arg1`. Sets the `Z` flag based on the result. Does not modify the `C` flag.

3. **ADD arg1, arg2**  
   **Code**: `0x0004 + 0x100 * arg1 + 0x0800 * arg2`  
   Adds `arg2` to `arg1`, storing the result in `arg1`. Sets the `Z` flag based on the result. Does not modify the `C` flag.

4. **SUB arg1, arg2**  
   **Code**: `0x0005 + 0x100 * arg1 + 0x0800 * arg2`  
   Subtracts `arg2` from `arg1`, storing the result in `arg1`. Sets the `Z` flag based on the result. Does not modify the `C` flag.

5. **ADC arg1, arg2**  
   **Code**: `0x0006 + 0x100 * arg1 + 0x0800 * arg2`  
   Adds `arg2` and the `C` flag to `arg1`, storing the result in `arg1`. Sets the `C` and `Z` flags based on the result.

6. **SBB arg1, arg2**  
   **Code**: `0x0007 + 0x100 * arg1 + 0x0800 * arg2`  
   Subtracts `arg2` and the `C` flag from `arg1`, storing the result in `arg1`. Sets the `C` and `Z` flags based on the result.

7. **MOVI arg1, imm8**  
   **Code**: `0x4000 + 0x100 * arg1 + imm8`  
   Copies the 8-bit constant `imm8` to `arg1`. Does not modify flags.

8. **XORI arg1, imm8**  
   **Code**: `0x5800 + 0x100 * arg1 + imm8`  
   Performs a bitwise XOR between `arg1` and `imm8`, storing the result in `arg1`. Sets the `Z` flag based on the result. Does not modify the `C` flag.

9. **ADDI arg1, imm8**  
   **Code**: `0x6000 + 0x100 * arg1 + imm8`  
   Adds `imm8` to `arg1`, storing the result in `arg1`. Sets the `Z` flag based on the result. Does not modify the `C` flag.

10. **CMPI arg1, imm8**  
    **Code**: `0x6800 + 0x100 * arg1 + imm8`  
    Subtracts `imm8` from `arg1` without storing the result. Sets the `C` and `Z` flags based on the result.

11. **RCR arg1**  
    **Code**: `0x7001 + 0x100 * arg1`  
    Rotates `arg1` right by one bit through the `C` flag. Does not modify the `Z` flag.

12. **CLC**  
    **Code**: `0x8000`  
    Clears the `C` flag. Does not modify the `Z` flag.

13. **STC**  
    **Code**: `0x8100`  
    Sets the `C` flag. Does not modify the `Z` flag.

14. **JMP imm8**  
    **Code**: `0xC000 + imm8`  
    Performs an unconditional relative jump by `imm8`. Does not modify flags.

15. **JNC imm8**  
    **Code**: `0xC200 + imm8`  
    Performs a relative jump by `imm8` if the `C` flag is not set. Does not modify flags.

16. **JC imm8**  
    **Code**: `0xC300 + imm8`  
    Performs a relative jump by `imm8` if the `C` flag is set. Does not modify flags.

17. **JNZ imm8**  
    **Code**: `0xC400 + imm8`
    Performs a relative jump by `imm8` if the `Z` flag is not set. Does not modify flags.

18. **JZ imm8**  
    **Code**: `0xC500 + imm8`
    Performs a relative jump by `imm8` if the `Z` flag is set. Does not modify flags.

19. **BRK**  
    **Code**: `0xFFFF`
    Triggers a trap, halting the SO processor. Does not modify registers or status flags.

### Multi-Core Processor Instructions

The multi-core processor supports all single-core processor instructions and additionally the following instruction:

1. **XCHG arg1, arg2**: `0x0008 + 0x100 * arg1 + 0x0800 * arg2`
   Swaps the values of `arg1` and `arg2`. Does not modify flags. If `arg1` points to memory and `arg2` is a register, the instruction is atomic. If `arg2` points to memory, it is not atomic.

## Additional Details

The processor's behavior for invalid instruction codes is undefined, but ignoring such codes is recommended. It can be assumed that function parameters are always valid. To maintain compatibility, the single-core version should ignore the `core` parameter and the `CORES` constant. When the emulator encounters a `BRK` instruction, it executes it and then exits the `so_emul` function. In a multi-core processor, `BRK` halts `so_emul` for the core that encounters it.

### Usage
```bash
nasm -DCORES=$N -f elf64 -w+all -w+error -o so_emulator.o so_emulator.asm
```
where `$N` is the value of the `CORES` constant.

### Usage Examples

Example tests are in the attached file `so_emulator_example.c`. Compile with:

```bash
gcc -DCORES=4 -c -Wall -Wextra -std=c17 -O2 -o so_emulator_example.o so_emulator_example.c
gcc -pthread -o so_emulator_example so_emulator_example.o so_emulator.o
```

Run the tests with:

```bash
./so_emulator_example
./so_emulator_example 61 18
./so_emulator_example 10240
```

The file `so_emulator_example.out` contains the terminal output from the above commands.
