param (
    [string] $Path,
    [string] $CompilerPath,
    [string] $Configuration,
    [string] $PreprocessorSymbols,
    [string] $IdRanges,
    [string] $ReservationsManagerUrl,
    [string] $ReservationsManagerUser,
    [string] $ReservationsManagerPassword
)

import-module T3PALAppsBuilder

Check-T3PALFolderObjectReservation -Path $Path -CompilerPath $CompilerPath -Configuration $Configuration -PreprocessorSymbols $PreprocessorSymbols -IdRanges $IdRanges -ReservationsManagerUrl $ReservationsManagerUrl -ReservationsManagerUser $ReservationsManagerUser -ReservationsManagerPassword $ReservationsManagerPassword
