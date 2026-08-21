package org.jabref.logic.bst;

import java.util.List;

import org.junit.jupiter.api.Test;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;

/// Edge cases for the BST VM built-in functions: functions not exercised by
/// {@link BstFunctionsTest} (`text.prefix$`, `stack$`, `top$`, `warning$`)
/// and the type-guard / error branches of the remaining ones.
class BstFunctionsEdgeCasesTest {
    @Test
    void textPrefix() {
        BstVM vm = new BstVM("""
                FUNCTION { test } {
                    "Jonathan Meyer and Charles Louis Xavier Joseph de la Vall{\\'e}e Poussin" #5 text.prefix$
                    "abcd{efg}hi" #5 text.prefix$
                    "Hi {{\\oe   }}Hi " #5 text.prefix$
                }
                EXECUTE { test }
                """);

        vm.render(List.of());

        assertEquals("Hi {{\\o}}", vm.getContext().stack().pop());
        assertEquals("abcd{e}", vm.getContext().stack().pop());
        assertEquals("Jonat", vm.getContext().stack().pop());
        assertEquals(0, vm.getContext().stack().size());
    }

    @Test
    void textPrefixTypeGuardsPushEmptyString() {
        BstVM vm = new BstVM("""
                FUNCTION { test } {
                    "string" "not an integer" text.prefix$
                    #1 #2 text.prefix$
                }
                EXECUTE { test }
                """);

        vm.render(List.of());

        // Both calls hit a type guard: text.prefix$ pushes "" and returns
        // WITHOUT popping its second operand, which stays on the stack.
        assertEquals("", vm.getContext().stack().pop());
        assertEquals("", vm.getContext().stack().pop());
        assertEquals("string", vm.getContext().stack().pop());
        assertEquals(0, vm.getContext().stack().size());
    }

    @Test
    void purifyWithTypeMismatchPushesEmptyString() {
        BstVM vm = new BstVM("""
                FUNCTION { test } { #1 purify$ }
                EXECUTE { test }
                """);

        vm.render(List.of());

        assertEquals("", vm.getContext().stack().pop());
    }

    @Test
    void widthWithTypeMismatchPushesZero() {
        BstVM vm = new BstVM("""
                FUNCTION { test } { #1 width$ }
                EXECUTE { test }
                """);

        vm.render(List.of());

        assertEquals(0, vm.getContext().stack().pop());
    }

    @Test
    void stackFunctionPopsEverything() {
        BstVM vm = new BstVM("""
                FUNCTION { test } { #1 "a" #2 stack$ }
                EXECUTE { test }
                """);

        vm.render(List.of());

        assertEquals(0, vm.getContext().stack().size());
    }

    @Test
    void topPopsTopOfStack() {
        BstVM vm = new BstVM("""
                FUNCTION { test } { #1 #2 top$ }
                EXECUTE { test }
                """);

        vm.render(List.of());

        assertEquals(1, vm.getContext().stack().size());
        assertEquals(1, vm.getContext().stack().pop());
    }

    @Test
    void warningPopsTopOfStack() {
        BstVM vm = new BstVM("""
                FUNCTION { test } { "a message" warning$ }
                EXECUTE { test }
                """);

        vm.render(List.of());

        assertEquals(0, vm.getContext().stack().size());
    }

    @Test
    void greaterThanTypeMismatch() {
        BstVM vm = new BstVM("""
                FUNCTION { test } { #1 "a" > }
                EXECUTE { test }
                """);

        assertThrows(BstVMException.class, () -> vm.render(List.of()));
    }

    @Test
    void lowerThanTypeMismatch() {
        BstVM vm = new BstVM("""
                FUNCTION { test } { "a" #1 < }
                EXECUTE { test }
                """);

        assertThrows(BstVMException.class, () -> vm.render(List.of()));
    }

    @Test
    void subtractTypeMismatch() {
        BstVM vm = new BstVM("""
                FUNCTION { test } { #1 "a" - }
                EXECUTE { test }
                """);

        assertThrows(BstVMException.class, () -> vm.render(List.of()));
    }

    @Test
    void concatTypeMismatch() {
        BstVM vm = new BstVM("""
                FUNCTION { test } { "a" #1 * }
                EXECUTE { test }
                """);

        assertThrows(BstVMException.class, () -> vm.render(List.of()));
    }

    @Test
    void addPeriodTypeMismatch() {
        BstVM vm = new BstVM("""
                FUNCTION { test } { #1 add.period$ }
                EXECUTE { test }
                """);

        assertThrows(BstVMException.class, () -> vm.render(List.of()));
    }

    @Test
    void changeCaseFormatNotLengthOne() {
        BstVM vm = new BstVM("""
                FUNCTION { test } { "ab" "Hello" change.case$ }
                EXECUTE { test }
                """);

        assertThrows(BstVMException.class, () -> vm.render(List.of()));
    }

    @Test
    void changeCaseSecondParameterNotAString() {
        BstVM vm = new BstVM("""
                FUNCTION { test } { "t" #1 change.case$ }
                EXECUTE { test }
                """);

        assertThrows(BstVMException.class, () -> vm.render(List.of()));
    }

    @Test
    void chrToIntNotLengthOne() {
        BstVM vm = new BstVM("""
                FUNCTION { test } { "ab" chr.to.int$ }
                EXECUTE { test }
                """);

        assertThrows(BstVMException.class, () -> vm.render(List.of()));
    }

    @Test
    void numNamesTypeMismatch() {
        BstVM vm = new BstVM("""
                FUNCTION { test } { #1 num.names$ }
                EXECUTE { test }
                """);

        assertThrows(BstVMException.class, () -> vm.render(List.of()));
    }

    @Test
    void substringTypeMismatch() {
        BstVM vm = new BstVM("""
                FUNCTION { test } { "a" "b" "c" substring$ }
                EXECUTE { test }
                """);

        assertThrows(BstVMException.class, () -> vm.render(List.of()));
    }
}