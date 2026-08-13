# ============================================================
# SkyFactory 3 - Sieve Registry -> CSV
# ============================================================

# --- CONFIGURATION ---

$modpackRoot = "S:\Curseforge\Minecraft\Instances\FTB Presents SkyFactory 3"

$registryFile = Join-Path $modpackRoot "config\exnihiloadscensio\SieveRegistry.json"

$outputCsv = Join-Path $modpackRoot "sieve_recipes.csv"


# --- CHECK REGISTRY EXISTS ---

if (-not (Test-Path $registryFile)) {
    Write-Error "SieveRegistry.json not found at:`n$registryFile"
    exit 1
}

Write-Host "Loading SkyFactory 3 sieve registry..." -ForegroundColor Cyan
Write-Host $registryFile
Write-Host ""


# --- LOAD JSON ---

try {
    $registry = Get-Content -Raw -Path $registryFile | ConvertFrom-Json
}
catch {
    Write-Error "Failed to parse SieveRegistry.json"
    Write-Error $_
    exit 1
}


# --- PARSE SIEVE RECIPES ---

$recipes = @()

foreach ($inputProperty in $registry.PSObject.Properties) {

    # Example:
    # minecraft:soul_sand:0
    # minecraft:dirt:0
    # exnihiloadscensio:blockDust:0

    $input = $inputProperty.Name
    $drops = $inputProperty.Value

    # Track individual rolls for this input/output/mesh
    $rollCounters = @{}

    foreach ($entry in $drops) {

        $outputName = $entry.drop.name
        $outputMeta = [int]$entry.drop.meta

        $output = "$outputName`:$outputMeta"

        $tier = [int]$entry.meshLevel

        $chance = [math]::Round(
            ([double]$entry.chance * 100),
            4
        )

        $mesh = "Mesh $tier"

        # Unique key for identifying repeated rolls
        $rollKey = "$input|$output|$tier"

        if ($rollCounters.ContainsKey($rollKey)) {
            $rollCounters[$rollKey]++
        }
        else {
            $rollCounters[$rollKey] = 1
        }

        $roll = $rollCounters[$rollKey]

        $recipes += [PSCustomObject]@{
            Source     = "SieveRegistry"
            Input      = $input
            Mesh       = $mesh
            Output     = $output
            Count      = 1
            DropChance = "$chance`%"
            Tier       = $tier
            Roll       = $roll
        }
    }
}


# --- SORT ---

$recipes = $recipes |
    Sort-Object Tier, Input, Output, Roll


# --- DISPLAY ---

Write-Host ""
Write-Host "============================================" -ForegroundColor Cyan
Write-Host " SkyFactory 3 Sieve Registry" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""

$recipes | Format-Table -AutoSize


# --- EXPORT CSV ---

$recipes | Export-Csv `
    -Path $outputCsv `
    -NoTypeInformation `
    -Encoding UTF8


# --- SUMMARY ---

Write-Host ""
Write-Host "============================================" -ForegroundColor Green
Write-Host " Export complete!" -ForegroundColor Green
Write-Host "============================================" -ForegroundColor Green
Write-Host ""

Write-Host "Recipes : $($recipes.Count)"
Write-Host "CSV     : $outputCsv"
Write-Host ""

# Show duplicate/multiple-roll recipes
$multiRolls = $recipes |
    Group-Object Input, Output, Tier |
    Where-Object { $_.Count -gt 1 }

Write-Host "Multiple-roll combinations: $($multiRolls.Count)" -ForegroundColor Yellow

if ($multiRolls.Count -gt 0) {
    Write-Host ""
    Write-Host "Examples of multiple rolls:" -ForegroundColor Yellow

    foreach ($group in $multiRolls | Select-Object -First 20) {
        Write-Host "  $($group.Name) -> $($group.Count) rolls"
    }
}
