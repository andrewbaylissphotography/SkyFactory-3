# ============================================================
# SkyFactory 3
# Item Texture Extractor
#
# Minecraft 1.10.2
#
# Reads sieve_recipes.csv and extracts the required item
# textures from:
#
#   - Minecraft 1.10.2.jar
#   - Every mod JAR in the SkyFactory 3 mods folder
#
# The JARs are indexed ONCE.
# ============================================================


# ============================================================
# PATHS
# ============================================================

$csvPath = "C:\Users\andre\OneDrive\Documents\GitHub\SkyFactory 3\sieve_recipes.csv"

$modsFolder = "S:\Curseforge\Minecraft\Instances\FTB Presents SkyFactory 3\mods"

$minecraftJar = "S:\Curseforge\Minecraft\Install\versions\1.10.2\1.10.2.jar"

$destFolder = "C:\Users\andre\OneDrive\Documents\GitHub\SkyFactory 3\img\items"


# ============================================================
# LOG FILES
# ============================================================

$missingLogPath = Join-Path $destFolder "missing_unmapped_items.log"

$debugLogPath = Join-Path $destFolder "itemid_debug.log"


# ============================================================
# CREATE DESTINATION
# ============================================================

if (-not (Test-Path $destFolder)) {

    New-Item `
        -ItemType Directory `
        -Path $destFolder `
        -Force |
        Out-Null

}


# ============================================================
# CLEAR LOGS
# ============================================================

if (Test-Path $missingLogPath) {
    Remove-Item $missingLogPath -Force
}

if (Test-Path $debugLogPath) {
    Remove-Item $debugLogPath -Force
}


# ============================================================
# CHECK PATHS
# ============================================================

if (-not (Test-Path $csvPath)) {
    throw "CSV not found: $csvPath"
}

if (-not (Test-Path $modsFolder)) {
    throw "Mods folder not found: $modsFolder"
}

if (-not (Test-Path $minecraftJar)) {
    throw "Minecraft JAR not found: $minecraftJar"
}


# ============================================================
# LOAD CSV
# ============================================================

Write-Host ""
Write-Host "Loading CSV..." -ForegroundColor Cyan

$csvData = Import-Csv $csvPath


# ============================================================
# COLLECT UNIQUE ITEMS
#
# Both Input and Output are needed because the web page
# displays images for both sides.
# ============================================================

$itemIds = New-Object System.Collections.Generic.HashSet[string]

foreach ($row in $csvData) {

    if (-not [string]::IsNullOrWhiteSpace($row.Input)) {
        [void]$itemIds.Add($row.Input.Trim())
    }

    if (-not [string]::IsNullOrWhiteSpace($row.Output)) {
        [void]$itemIds.Add($row.Output.Trim())
    }

}


Write-Host "Unique items found: $($itemIds.Count)" -ForegroundColor Green


# ============================================================
# CUSTOM TEXTURE MAPPINGS
#
# Key:
#     CSV item ID
#
# Value:
#     Texture filename without .png
#
# These are checked before the automatic lookup.
# ============================================================

$customMappings = @{

    # ========================================================
    # minecraft
    # ========================================================

    "minecraft:dye:0"  = "dye_powder_black"
    "minecraft:dye:1"  = "dye_powder_red"
    "minecraft:dye:2"  = "dye_powder_green"
    "minecraft:dye:3"  = "dye_powder_brown"
    "minecraft:dye:4"  = "dye_powder_blue"
    "minecraft:dye:5"  = "dye_powder_purple"
    "minecraft:dye:6"  = "dye_powder_cyan"
    "minecraft:dye:7"  = "dye_powder_silver"
    "minecraft:dye:8"  = "dye_powder_gray"
    "minecraft:dye:9"  = "dye_powder_pink"
    "minecraft:dye:10" = "dye_powder_lime"
    "minecraft:dye:11" = "dye_powder_yellow"
    "minecraft:dye:12" = "dye_powder_light_blue"
    "minecraft:dye:13" = "dye_powder_magenta"
    "minecraft:dye:14" = "dye_powder_orange"
    "minecraft:dye:15" = "dye_powder_white"

    "minecraft:melon_seeds:0"   = "seeds_melon"
    "minecraft:pumpkin_seeds:0" = "seeds_pumpkin"
    "minecraft:wheat_seeds:0"   = "seeds_wheat"

    "minecraft:brown_mushroom:0" = "brown_mushroom"
    "minecraft:red_mushroom:0"   = "red_mushroom"
    "minecraft:redstone:0"       = "redstone_dust"

    # ========================================================
    # exnihiloadscensio
    # ========================================================

"exnihiloadscensio:itemSeedAcacia:0"    = "seedAcacia"
"exnihiloadscensio:itemSeedBirch:0"     = "seedBirch"
"exnihiloadscensio:itemSeedCarrot:0"    = "seedCarrot"
"exnihiloadscensio:itemSeedDarkOak:0"   = "seedDarkOak"
"exnihiloadscensio:itemSeedJungle:0"    = "seedJungle"
"exnihiloadscensio:itemSeedOak:0"       = "seedOak"
"exnihiloadscensio:itemSeedPotato:0"    = "seedPotato"
"exnihiloadscensio:itemSeedSpruce:0"    = "seedSpruce"
"exnihiloadscensio:itemSeedSugarcane:0" = "seedSugarCane"
"exnihiloadscensio:itemSeedCactus:0"    = "seedCactus"

}



# ============================================================
# TEXTURE INDEX
#
# Key:
#
#     namespace|filename
#
# Example:
#
#     minecraft|dye_powder_cyan
#
# Value:
#
#     path inside the JAR
#
# Example:
#
#     assets/minecraft/textures/items/dye_powder_cyan.png
# ============================================================

$textureIndex = @{}

# Keep track of which JAR provided each texture.
$textureSourceIndex = @{}

# Number of textures indexed.
$totalTexturesIndexed = 0


# ============================================================
# FUNCTION:
# ADD TEXTURE TO INDEX
# ============================================================

function Add-TextureToIndex {

    param(
        [string]$namespace,
        [string]$textureName,
        [string]$jarPath,
        [string]$entryPath
    )


    if ([string]::IsNullOrWhiteSpace($namespace)) {
        return
    }

    if ([string]::IsNullOrWhiteSpace($textureName)) {
        return
    }


    $cleanName =
        [System.IO.Path]::GetFileNameWithoutExtension(
            $textureName
        )


    if ([string]::IsNullOrWhiteSpace($cleanName)) {
        return
    }


    $key =
        $namespace.ToLowerInvariant() +
        "|" +
        $cleanName.ToLowerInvariant()


    # --------------------------------------------------------
    # First match wins.
    #
    # Minecraft is indexed first, followed by mods.
    # --------------------------------------------------------

    if (-not $textureIndex.ContainsKey($key)) {

        $textureIndex[$key] = $entryPath

        $textureSourceIndex[$key] = $jarPath

        $script:totalTexturesIndexed++

    }

}


# ============================================================
# FUNCTION:
# INDEX A JAR
#
# This opens the JAR once and indexes all relevant PNG files.
# ============================================================

function Index-Jar {

    param(
        [string]$jarPath
    )


    Write-Host ""
    Write-Host "Indexing:" -ForegroundColor Yellow
    Write-Host "  $jarPath"


    try {

        Add-Type -AssemblyName System.IO.Compression.FileSystem -ErrorAction SilentlyContinue

        $zip = [System.IO.Compression.ZipFile]::OpenRead($jarPath)


        try {

            foreach ($entry in $zip.Entries) {

                $entryName = $entry.FullName


                # ------------------------------------------------
                # Only assets textures.
                # ------------------------------------------------

                if (-not $entryName.StartsWith("assets/")) {
                    continue
                }


                # ------------------------------------------------
                # Only PNG files.
                # ------------------------------------------------

                if (-not $entryName.EndsWith(".png", [System.StringComparison]::OrdinalIgnoreCase)) {
                    continue
                }


                # ------------------------------------------------
                # Parse:
                #
                # assets/<namespace>/<path>
                # ------------------------------------------------

                $parts =
                    $entryName.Split("/")


                if ($parts.Count -lt 3) {
                    continue
                }


                $namespace = $parts[1]


                # ------------------------------------------------
                # We care about item/block textures.
                #
                # We deliberately accept both old:
                #
                # textures/item
                # textures/items
                #
                # and blocks:
                #
                # textures/block
                # textures/blocks
                #
                # Some 1.10.2 mods use unusual layouts, so
                # filename-only lookup later can still find them.
                # ------------------------------------------------

                $isTexture =
                    $entryName -match "/textures/item/" -or
                    $entryName -match "/textures/items/" -or
                    $entryName -match "/textures/block/" -or
                    $entryName -match "/textures/blocks/"


                if (-not $isTexture) {
                    continue
                }


                # ------------------------------------------------
                # Get filename without extension.
                # ------------------------------------------------

                $filename =
                    [System.IO.Path]::GetFileNameWithoutExtension(
                        $entryName
                    )


                if ([string]::IsNullOrWhiteSpace($filename)) {
                    continue
                }


                Add-TextureToIndex `
                    -namespace $namespace `
                    -textureName $filename `
                    -jarPath $jarPath `
                    -entryPath $entryName

            }

        }
        finally {

            $zip.Dispose()

        }

    }
    catch {

        Write-Warning "Could not read JAR: $jarPath"

        Write-Warning $_.Exception.Message

    }

}


# ============================================================
# INDEX MINECRAFT FIRST
# ============================================================

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "INDEXING MINECRAFT" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

Index-Jar $minecraftJar


# ============================================================
# FIND MOD JARS
# ============================================================

$modJars =
    Get-ChildItem `
        -Path $modsFolder `
        -Filter "*.jar" `
        -File `
        -Recurse


Write-Host ""
Write-Host "Mod JARs found: $($modJars.Count)" -ForegroundColor Green


# ============================================================
# INDEX MOD JARS
# ============================================================

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "INDEXING MODS" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan


$modCounter = 0

foreach ($modJar in $modJars) {

    $modCounter++

    Write-Host ""
    Write-Host "[$modCounter / $($modJars.Count)]" -ForegroundColor DarkGray

    Index-Jar $modJar.FullName

}


# ============================================================
# INDEX SUMMARY
# ============================================================

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "INDEX COMPLETE" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

Write-Host "Textures indexed: $totalTexturesIndexed" -ForegroundColor Green


# ============================================================
# FUNCTION:
# GET TEXTURE FOR ITEM
# ============================================================

function Find-Texture {

    param(
        [string]$itemId
    )


    if ([string]::IsNullOrWhiteSpace($itemId)) {
        return $null
    }


    # --------------------------------------------------------
    # Remove [TAG] prefix if present.
    # --------------------------------------------------------

    $cleanItemId =
        $itemId -replace '^\[TAG\]\s*', ''


    # --------------------------------------------------------
    # Parse:
    #
    # namespace:item:metadata
    #
    # We split from the RIGHT so that this works safely with
    # the old metadata format.
    # --------------------------------------------------------

    $parts =
        $cleanItemId.Split(":")


    if ($parts.Count -lt 2) {
        return $null
    }


    $namespace =
        $parts[0].ToLowerInvariant()


    $itemName =
        $parts[1].ToLowerInvariant()


    $metadata = "0"

    if ($parts.Count -ge 3) {
        $metadata = $parts[2]
    }


    # ========================================================
    # 1. CUSTOM MAPPING
    # ========================================================

    if ($customMappings.ContainsKey($cleanItemId)) {

        $mappedName =
            $customMappings[$cleanItemId]


        $key =
            $namespace +
            "|" +
            $mappedName.ToLowerInvariant()


        if ($textureIndex.ContainsKey($key)) {

            return $textureIndex[$key]

        }

    }


    # ========================================================
    # 2. SPECIAL MINECRAFT DYE HANDLING
    #
    # The CSV ID is:
    #
    # minecraft:dye:4
    #
    # But Minecraft 1.10.2 texture is:
    #
    # dye_powder_blue.png
    # ========================================================

    if (
        $namespace -eq "minecraft" -and
        $itemName -eq "dye"
    ) {

        $dyeNames = @{

            "0"  = "dye_powder_black"
            "1"  = "dye_powder_red"
            "2"  = "dye_powder_green"
            "3"  = "dye_powder_brown"
            "4"  = "dye_powder_blue"
            "5"  = "dye_powder_purple"
            "6"  = "dye_powder_cyan"
            "7"  = "dye_powder_silver"
            "8"  = "dye_powder_gray"
            "9"  = "dye_powder_pink"
            "10" = "dye_powder_lime"
            "11" = "dye_powder_yellow"
            "12" = "dye_powder_light_blue"
            "13" = "dye_powder_magenta"
            "14" = "dye_powder_orange"
            "15" = "dye_powder_white"

        }


        if ($dyeNames.ContainsKey($metadata)) {

            $dyeTexture =
                $dyeNames[$metadata]


            $key =
                "minecraft|" +
                $dyeTexture


            if ($textureIndex.ContainsKey($key)) {

                return $textureIndex[$key]

            }

        }

    }


    # ========================================================
    # 3. NORMAL ITEM NAME
    #
    # Example:
    #
    # minecraft:flint:0
    #
    # searches:
    #
    # flint
    # ========================================================

    $candidates = @(
        $itemName
    )


    # ========================================================
    # 4. METADATA FILENAMES
    #
    # Some mods use:
    #
    # item_0
    # item_1
    #
    # or:
    #
    # item0
    # ========================================================

    if ($metadata -ne "0") {

        $candidates +=
            $itemName + "_" + $metadata

        $candidates +=
            $itemName + $metadata

    }


    # ========================================================
    # 5. TRY EACH CANDIDATE
    # ========================================================

    foreach ($candidate in $candidates) {

        $candidateLower =
            $candidate.ToLowerInvariant()


        $key =
            $namespace +
            "|" +
            $candidateLower


        if ($textureIndex.ContainsKey($key)) {

            return $textureIndex[$key]

        }

    }


    # ========================================================
    # 6. FALLBACK:
    # SEARCH BY NAMESPACE + FILENAME
    #
    # This helps with odd old mod asset layouts.
    # ========================================================

    foreach ($entry in $textureIndex.GetEnumerator()) {

        $keyParts =
            $entry.Key.Split("|")


        if ($keyParts.Count -ne 2) {
            continue
        }


        if ($keyParts[0] -ne $namespace) {
            continue
        }


        $filename =
            $keyParts[1]


        foreach ($candidate in $candidates) {

            if ($filename -eq $candidate.ToLowerInvariant()) {

                return $entry.Value

            }

        }

    }


    # ========================================================
    # Nothing found.
    # ========================================================

    return $null

}


# ============================================================
# FUNCTION:
# EXTRACT ZIP ENTRY
# ============================================================

function Extract-Texture {

    param(
        [string]$jarPath,
        [string]$entryPath,
        [string]$destination
    )


    try {

        Add-Type -AssemblyName System.IO.Compression.FileSystem -ErrorAction SilentlyContinue

        $zip =
            [System.IO.Compression.ZipFile]::OpenRead(
                $jarPath
            )


        try {

            $entry =
                $zip.GetEntry($entryPath)


            if ($null -eq $entry) {
                return $false
            }


            $stream =
                $entry.Open()


            try {

                $fileStream =
                    [System.IO.File]::Create(
                        $destination
                    )


                try {

                    $stream.CopyTo($fileStream)

                }
                finally {

                    $fileStream.Dispose()

                }

            }
            finally {

                $stream.Dispose()

            }

        }
        finally {

            $zip.Dispose()

        }


        return $true

    }
    catch {

        Write-Warning "Failed extracting $entryPath"

        Write-Warning $_.Exception.Message

        return $false

    }

}


# ============================================================
# EXTRACT ITEMS
# ============================================================

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "EXTRACTING ITEM IMAGES" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan


$foundCount = 0

$missingCount = 0

$counter = 0


foreach ($itemId in $itemIds) {

    $counter++


    Write-Host ""
    Write-Host "[$counter / $($itemIds.Count)] $itemId" -ForegroundColor White


    # --------------------------------------------------------
    # Output filename
    #
    # Matches the JavaScript:
    #
    # replace(/[:.]/g, "_")
    #
    # Example:
    #
    # minecraft:dye:4
    #
    # becomes:
    #
    # minecraft_dye_4.png
    # --------------------------------------------------------

    $safeFilename =
        $itemId `
            -replace ":", "_" `
            -replace "\.", "_"


    $safeFilename =
        $safeFilename.ToLowerInvariant()


    $destination =
        Join-Path `
            $destFolder `
            ($safeFilename + ".png")


    # --------------------------------------------------------
    # Find texture
    # --------------------------------------------------------

    $textureEntry =
        Find-Texture $itemId


    if ($null -eq $textureEntry) {

        Write-Host "  NOT FOUND" -ForegroundColor Red

        Add-Content `
            -Path $missingLogPath `
            -Value $itemId

        Add-Content `
            -Path $debugLogPath `
            -Value "[MISSING] $itemId"

        $missingCount++

        continue

    }


    # --------------------------------------------------------
    # Determine which JAR owns the texture.
    # --------------------------------------------------------

    $parts =
        $itemId.Split(":")


    $namespace =
        $parts[0].ToLowerInvariant()


    $filename =
        [System.IO.Path]::GetFileNameWithoutExtension(
            $textureEntry
        )


    $indexKey =
        $namespace +
        "|" +
        $filename.ToLowerInvariant()


    $sourceJar =
        $textureSourceIndex[$indexKey]


    # --------------------------------------------------------
    # Extract
    # --------------------------------------------------------

    $success =
        Extract-Texture `
            -jarPath $sourceJar `
            -entryPath $textureEntry `
            -destination $destination


    if ($success) {

        Write-Host "  FOUND: $filename.png" -ForegroundColor Green

        Write-Host "  From:  $sourceJar" -ForegroundColor DarkGray

        Write-Host "  To:    $destination" -ForegroundColor DarkGray


        Add-Content `
            -Path $debugLogPath `
            -Value "[FOUND] $itemId -> $textureEntry -> $sourceJar"


        $foundCount++

    }
    else {

        Write-Host "  EXTRACTION FAILED" -ForegroundColor Red

        Add-Content `
            -Path $missingLogPath `
            -Value $itemId

        Add-Content `
            -Path $debugLogPath `
            -Value "[EXTRACTION FAILED] $itemId -> $textureEntry"


        $missingCount++

    }

}


# ============================================================
# SUMMARY
# ============================================================

Write-Host ""
Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "DONE" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Cyan

Write-Host ""
Write-Host "Unique CSV items : $($itemIds.Count)"
Write-Host "Textures indexed : $totalTexturesIndexed"
Write-Host "Images found     : $foundCount" -ForegroundColor Green
Write-Host "Images missing   : $missingCount" -ForegroundColor Yellow

Write-Host ""
Write-Host "Images:"
Write-Host "  $destFolder"

Write-Host ""
Write-Host "Missing log:"
Write-Host "  $missingLogPath"

Write-Host ""
Write-Host "Debug log:"
Write-Host "  $debugLogPath"

Write-Host ""
