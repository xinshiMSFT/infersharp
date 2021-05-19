// Copyright (c) Microsoft Corporation.
// Licensed under the MIT License.
using Cilsil.Utils;
using Mono.Cecil.Cil;

namespace Cilsil.Cil.Parsers
{
    internal class LeaveParser : InstructionParser
    {
        protected override bool ParseCilInstructionInternal(Instruction instruction,
                                                            ProgramState state)
        {
            switch (instruction.OpCode.Code)
            {   
                case Code.Leave:
                case Code.Leave_S:
                    var nextInstruction = instruction.Next;
                    var targetTrue = instruction.Operand as Instruction;

                    state.AppendToPreviousNode = false;

                    // If there are concatenated finally blocks (such as multi-variable using), 
                    // we ignore the connections between try block and each finally block. Instead we
                    // only connect the try block with the starting finally block. 
                    if (IsConcatenatedFinally(state, instruction))
                    {
                        state.PushInstruction(targetTrue);
                        return true;
                    }

                    if (nextInstruction != null &&
                        targetTrue.Offset != nextInstruction.Offset &&
                        (!state.ParsedInstructions.Contains(nextInstruction) ||
                        instruction.Previous.OpCode.Code == Code.Endfinally))
                    {
                        state.PushInstruction(nextInstruction);
                    }
                    state.PushInstruction(targetTrue);
                    return true;
                default:
                    return false;
            }
        }

        /// <summary>
        /// Checks if the Leave instruction under process is concatenating two finally blocks.
        /// </summary>
        /// <param name="state">Current program state.</param>
        /// <param name="currentInstruction">The current Leave instruction under process.</param>
        /// <returns>Returns <c>true</c> if this Leave instruction is in the middle of two finally blocks, 
        /// and <c>false</c> otherwise.</returns>
        private bool IsConcatenatedFinally(ProgramState state, Instruction currentInstruction)
        {
            return (state.ParsedInstructions[state.ParsedInstructions.Count - 2].OpCode.Code == Code.Leave_S &&
                   currentInstruction.Previous.OpCode.Code == Code.Endfinally && 
                   state.ExceptionBlockStartToEndOffsets.ContainsKey(currentInstruction.Next.Offset) &&
                   !state.OffsetToExceptionType.ContainsKey(currentInstruction.Next.Offset));
        }
    }
}