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

                    if (targetTrue.Offset != nextInstruction.Offset &&
                        !state.ParsedInstructions.Contains(nextInstruction))
                    {
                        state.PushInstruction(nextInstruction);
                    }
                    // When jumping to the target true instruction is for loading the returned variables for 
                    // exception handling, we ignore registering these nodes.
                    if (state.ExceptionBlockStartToEndOffsets.ContainsKey(nextInstruction.Offset) &&
                        !state.OffsetToExceptionType.ContainsKey(nextInstruction.Offset))
                    {
                        return true;
                    }
                    state.PushInstruction(targetTrue);
                    return true;
                default:
                    return false;
            }
        }
    }
}