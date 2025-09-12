; Test Access Violation - Tentative d'accès mémoire invalide
DllCall("kernel32.dll\WriteProcessMemory", "Ptr", 0, "Ptr", 0x1000, "AStr", "Test", "UInt", 4, "Ptr", 0)
