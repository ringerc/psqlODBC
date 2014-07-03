if (! $configInfo)
{
    throw "Run buildX64-installer.ps1 or buildX86installer.ps1 instead";
}

$VERSION = $configInfo.Configuration.version

$archinfo = $configInfo.Configuration.$CPUTYPE

$LIBPQVER=$archinfo.libpq.version
if ($LIBPQVER -eq "") {
	$LIBPQVER=$LIBPQ_VERSION
}

$USE_LIBPQ=$archinfo.use_libpq

if ($CPUTYPE -eq "x64")
{
	if ($USE_LIBPQ -eq "yes")
	{
		$LIBPQBINDIR=$archinfo.libpq.bin
		if ($LIBPQBINDIR -eq "default") {
			if ($env:PROCESSOR_ARCHITECTURE -ne "x86") {
				$pgmfs = "$env:ProgramFiles"
				$LIBPQBINDIR = "$pgmfs\PostgreSQL\$LIBPQVER\bin"
			}
			elseif ("${env:ProgramW6432}" -ne "") {
				$pgmfs = "$env:ProgramW6432"
				$LIBPQBINDIR = "$pgmfs\PostgreSQL\$LIBPQVER\bin"
			}
		}
	}
	
}
elseif ($CPUTYPE -eq "x86")
{
	if ($USE_LIBPQ -eq "yes")
	{
		$LIBPQBINDIR=$archinfo.libpq.bin
		if ($env:PROCESSOR_ARCHITECTURE -eq "x86") {
			$pgmfs = "$env:ProgramFiles"
		} else {
			$pgmfs = "${env:ProgramFiles(x86)}"
		}
		if ($LIBPQBINDIR -eq "default") {
			$LIBPQBINDIR = "$pgmfs\PostgreSQL\$LIBPQVER\bin"
		}
	}

}
else
{
	throw "Unknown CPU type $CPUTYPE";
}

$USE_SSPI=$archinfo.use_sspi

$USE_GSS=$archinfo.use_gss
if ($USE_GSS -eq "yes")
{
	$GSSBINDIR=$archinfo.gss.bin
}

Write-Host "VERSION    : $VERSION"
Write-Host "USE LIBPQ  : $USE_LIBPQ ($LIBPQBINDIR)"
Write-Host "USE GSS    : $USE_GSS ($GSSBINDIR)"
Write-Host "USE SSPI   : $USE_SSPI"

if ($env:WIX -ne "")
{
	$wix = "$env:WIX"
	$env:Path += ";$WIX/bin"
}
# The subdirectory to install into
$SUBLOC=$VERSION.substring(0, 2) + $VERSION.substring(3, 2)

if (!(Test-Path -Path $CPUTYPE)) {
    New-Item -ItemType directory -Path $CPUTYPE
}

$PRODUCTCODE=$PRODUCTID[$VERSION]
if ("$PRODUCTCODE" -eq "") {
	Write-Host "`nSpecify the ProductCode for the VERSION $VERSION"
	return
}
Write-Host "PRODUCTCODE: $PRODUCTCODE"

try {
	pushd $scriptPath

	Write-Host ".`nBuilding psqlODBC/$SUBLOC merge module..."

	invoke-expression "candle -nologo -dPlatform=$CPUTYPE `"-dVERSION=$VERSION`" -dSUBLOC=$SUBLOC `"-dLIBPQBINDIR=$LIBPQBINDIR`" `"-dGSSBINDIR=$GSSBINDIR`" -o $CPUTYPE\psqlodbcm.wixobj psqlodbcm_cpu.wxs"

	Write-Host ".`nLinking psqlODBC merge module..."
	invoke-expression "light -nologo -o $CPUTYPE\psqlodbc_$CPUTYPE.msm $CPUTYPE\psqlodbcm.wixobj"

	Write-Host ".`nBuilding psqlODBC installer database..."

	invoke-expression "candle -nologo -dPlatform=$CPUTYPE `"-dVERSION=$VERSION`" -dSUBLOC=$SUBLOC `"-dPRODUCTCODE=$PRODUCTCODE`" -o $CPUTYPE\psqlodbc.wixobj psqlodbc_cpu.wxs"

	Write-Host ".`nLinking psqlODBC installer database..."
	invoke-expression "light -nologo -ext WixUIExtension -cultures:en-us -o $CPUTYPE\psqlodbc_$CPUTYPE.msi $CPUTYPE\psqlodbc.wixobj"

	Write-Host ".`nModifying psqlODBC installer database..."
	invoke-expression "cscript modify_msi.vbs $CPUTYPE\psqlodbc_$CPUTYPE.msi"

	Write-Host ".`nDone!"
}
catch {
	Write-Host ".`Aborting build!"
	throw $error[0]
}
finally {
	popd
}
