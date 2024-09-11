# Define default values
$striimInstallPath = Get-Location
$downloadDir = -join ($striimInstallPath, "\downloads")

# Create downloads folder if it doesn't exist
if (-not (Test-Path $downloadDir)) {
    New-Item -ItemType Directory -Force -Path $downloadDir
}

# Check for agent.conf or startUp.properties to determine node type
$agentConfPath = -join ($striimInstallPath, "\conf\agent.conf")
$startUpPropsPath = -join ($striimInstallPath, "\conf\startUp.properties")

if (Test-Path $agentConfPath) {
    $nodeType = "A"  # Agent
    Write-Host "Detected Agent environment based on agent.conf"
} elseif (Test-Path $startUpPropsPath) {
    $nodeType = "N"  # Node
    Write-Host "Detected Node environment based on startUp.properties"
} else {
    # If neither file is found, ask the user
    $nodeType = Read-Host "Is this Agent (default) or Node? (Enter 'A' for Agent or 'N' for Node)"
    if ($nodeType -eq "") { $nodeType = "A" }
    $nodeType = $nodeType.ToUpper()
}

# Ask user for Striim install path only if node type couldn't be auto-detected
if ($nodeType -eq "") {
    $striimInstallPathInput = Read-Host "Provide Striim install path or press Enter to default to $($striimInstallPath):"
    if ($striimInstallPathInput -ne "") {
        $striimInstallPath = $striimInstallPathInput
    }
    Write-Host "User set Striim Install Path set to: $striimInstallPath"
}

Write-Host "Striim Install Path set to: $striimInstallPath"

# Agent-specific checks
if ($nodeType -eq "A") {
    $agentConfPath = -join ($striimInstallPath, "\conf\agent.conf")

    # Check if agent.conf exists
    if (Test-Path $agentConfPath) {
        $agentConf = Get-Content $agentConfPath

        # Check for striim.cluster.clusterName
        if ($agentConf -match "striim\.cluster\.clusterName=") {
            Write-Host "'striim.cluster.clusterName' found in agent.conf"
        } else {
            Write-Host "'striim.cluster.clusterName' not found in agent.conf. Please provide a value."
        }

        # Check for striim.node.servernode.address
        if ($agentConf -match "striim\.node\.servernode\.address=") {
            Write-Host "'striim.node.servernode.address' found in agent.conf"
        } else {
            Write-Host "'striim.node.servernode.address' not found in agent.conf. Please provide a value."
        }
    } else {
        Write-Host "agent.conf not found in $($striimInstallPath)\conf"
    }
} 

# Node-specific checks
if ($nodeType -eq "N") {
    $startUpPropsPath = -join ($striimInstallPath, "\conf\startUp.properties")

    # Check if startUp.properties exists
    if (Test-Path $startUpPropsPath) {
        $startUpProps = Get-Content $startUpPropsPath

        # Check for required values
        $requiredProps = "CompanyName", "LicenceKey", "ProductKey", "WAClusterName"
        foreach ($prop in $requiredProps) {
            if ($startUpProps -match "$prop=") {
                Write-Host "'$prop' found in startUp.properties"
            } else {
                Write-Host "'$prop' not found in startUp.properties. Please provide a value."
            }
        }
    } else {
        Write-Host "startUp.properties not found in $($striimInstallPath)\conf"
    }
} 

# Check if Striim lib directory is in PATH
$striimLibPath = -join ($striimInstallPath, "\lib")
Write-Host "Striim Lib Path set to: $striimLibPath"
if ($env:Path -split ";" -contains $striimLibPath) {
    Write-Host "Striim lib directory found in PATH."
} else {
    Write-Host "Striim lib directory not found in PATH. Please add it."
}

# Check for required DLLs
$requiredDlls = "icudt72.dll", "icuuc72.dll", "MSSQLNative.dll"
foreach ($dll in $requiredDlls) {
    if (Test-Path "$striimLibPath\$dll") {
        Write-Host "$dll found in $striimLibPath"
    } else {
        # Offer to download DLLs
        $downloadChoice = Read-Host "  $striimLibPath\$dll not found. Download it? (Y/N)"
        if ($downloadChoice.ToUpper() -eq "Y") {
            # Create download directory if it doesn't exist
            if (-not (Test-Path $downloadDir)) {
                New-Item -ItemType Directory -Force -Path $downloadDir
            }

            if ($dll -eq "MSSQLNative.dll") {
                $downloadUrl = "https://github.com/daniel-striim/StriimQueryAutoLoader/raw/main/MSJet/MSSQLNative.dll"
            } else {
                $downloadUrl = "https://github.com/daniel-striim/StriimQueryAutoLoader/raw/main/MSJet/Dlls.zip"
            }

            $downloadPath = $downloadDir + "\" + $downloadUrl.Split("/")[-1]
            Invoke-WebRequest -Uri $downloadUrl -OutFile $downloadPath

            if ($downloadUrl.EndsWith(".zip")) {
                Expand-Archive -Path $downloadPath -DestinationPath $striimLibPath
            } else {
                Copy-Item $downloadPath $striimLibPath
            }

            Write-Host "$dll downloaded and extracted to $striimLibPath"
        }
    }
}

if (Get-Command java -ErrorAction SilentlyContinue) {
    $javaVersionOutput = java -version 2>&1 | Select-String -Pattern 'java version "(.*)"'
	Write-Host "Java version: $javaVersionOutput"
    if ($javaVersionOutput) {
        $javaVersion = $javaVersionOutput.Matches.Groups[1].Value
        if ($javaVersion -match "1\.8" -or $javaVersion -match "18\.0\.\d+\.\d+") {
            Write-Host "Java 8 found."
        } else {
            # Offer to download Java 8
            $downloadJavaChoice = Read-Host "  Java 8 not found. Download it? (Y/N)"
            if ($downloadJavaChoice.ToUpper() -eq "Y") {
                $javaDownloadUrl = "https://builds.openlogic.com/downloadJDK/openlogic-openjdk/8u422-b05/openlogic-openjdk-8u422-b05-windows-x64.msi"
                $javaDownloadPath = $downloadDir + "\" + $javaDownloadUrl.Split("/")[-1]
                Invoke-WebRequest -Uri $javaDownloadUrl -OutFile $javaDownloadPath
                Write-Host "Java 8 installer downloaded to $javaDownloadPath. Please install it."
            }
        }
    } else {
        Write-Host "Could not determine Java version." 
    }
} else {
    # Offer to download Java 8
    $downloadJavaChoice = Read-Host "Java not found. Download Java 8? (Y/N)"
    if ($downloadJavaChoice.ToUpper() -eq "Y") {
        $javaDownloadUrl = "https://builds.openlogic.com/downloadJDK/openlogic-openjdk/8u422-b05/openlogic-openjdk-8u422-b05-windows-x64.msi"
        $javaDownloadPath = $downloadDir + "\" + $javaDownloadUrl.Split("/")[-1]
        Invoke-WebRequest -Uri $javaDownloadUrl -OutFile $javaDownloadPath
        Write-Host "Java 8 installer downloaded to $javaDownloadPath. Please install it."
    }
} 

$sqljdbcAuthDllPath = "C:\Windows\System32\sqljdbc_auth.dll"
if (Test-Path $sqljdbcAuthDllPath) {
    Write-Host "sqljdbc_auth.dll found in C:\Windows\System32"
} else {
    # Ask about Integrated Security only if the DLL is missing
    $useIntegratedSecurity = Read-Host "Plan to use Integrated Security? (Y/N)"
    if ($useIntegratedSecurity.ToUpper() -eq "Y") {
        # Check if it exists in /lib
        if (Test-Path "$striimLibPath\sqljdbc_auth.dll") {
            $copyChoice = Read-Host "  sqljdbc_auth.dll found in $striimLibPath. Copy it to C:\Windows\System32? (Y/N)"
            if ($copyChoice.ToUpper() -eq "Y") {
                Copy-Item "$striimLibPath\sqljdbc_auth.dll" $sqljdbcAuthDllPath
                Write-Host "sqljdbc_auth.dll copied to C:\Windows\System32"
            }
        } else {
            # Offer to download
            $downloadChoice = Read-Host "  sqljdbc_auth.dll not found. Download it? (Y/N)"
            if ($downloadChoice.ToUpper() -eq "Y") {
                $downloadUrl = "https://github.com/daniel-striim/StriimQueryAutoLoader/raw/main/MSJet/sqljdbc_auth.dll" # Update with the correct URL if needed
                $downloadPath = $downloadDir + "\" + $downloadUrl.Split("/")[-1]
                Invoke-WebRequest -Uri $downloadUrl -OutFile $downloadPath
                Copy-Item $downloadPath $sqljdbcAuthDllPath
                Write-Host "sqljdbc_auth.dll downloaded and copied to C:\Windows\System32"
            }
        }
    }
}

Write-Host "Checking for installed requirements..."

# Get the list of installed software once
$installedSoftwareList = Get-WmiObject -Class Win32_Product 

Write-Host "Checking for installed requirements...Software list gathered."

function CheckAndDownloadSoftware {
    param(
        [string]$softwareName,
        [string]$requiredVersion,
        [string]$downloadUrl
    )

    $matchingSoftware = $installedSoftwareList | 
                        Where-Object { 
                            $_.Name -like "*$softwareName*" 
                        } 

    if ($matchingSoftware) {
        foreach ($software in $matchingSoftware) {
            if ([version]$software.Version -ge [version]$requiredVersion) {
                Write-Host "$($software.Name) version $($software.Version) found. Meets requirement."
            } else {
                Write-Host "$($software.Name) version $($software.Version) found, but it's too old."
                DownloadAndInstallSoftware $softwareName $downloadUrl
            }
        }
    } else {
        Write-Host "$softwareName not found." 
        DownloadAndInstallSoftware $softwareName $downloadUrl
    }
}

# Function to download and provide instructions for software installation
function DownloadAndInstallSoftware {
    param(
        [string]$softwareName,
        [string]$downloadUrl
    )

    $downloadChoice = Read-Host "  Do you want to download and install $softwareName? (Y/N)"
    if ($downloadChoice.ToUpper() -eq "Y") {
		[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
		
        $downloadPath = $downloadDir + "\" + $downloadUrl.Split("/")[-1]
        Invoke-WebRequest -Uri $downloadUrl -OutFile $downloadPath
        Write-Host "$softwareName installer downloaded to $downloadPath. Please run it to install."
    }
}

# Check for Microsoft Visual C++ 2015-2019 Redistributable
CheckAndDownloadSoftware "Microsoft Visual C++ 2019 X64 Minimum Runtime" "14.28.29914" "https://aka.ms/vs/16/release/14.29.30133/VC_Redist.x64.exe"

# Check for Microsoft OLE DB Driver for SQL Server
CheckAndDownloadSoftware "Microsoft OLE DB Driver for SQL Server" "18.2.3.0" "https://go.microsoft.com/fwlink/?linkid=2119554"


# Check if Striim service is installed
$runAsService = Read-Host "Plan to run Striim as a service? (Y/N)"
if ($runAsService.ToUpper() -eq "Y") {
    if (Get-Service Striim -ErrorAction SilentlyContinue) {
        Write-Host "Striim service is installed."
    } else {
        # Check for windowsService/windowsAgent folder
        if ($nodeType -eq "A") { 
			$serviceConfigFolder = -join ($striimInstallPath, "\conf\windowsAgent")
		} else { 
			$serviceConfigFolder = -join ($striimInstallPath, "\conf\windowsService")
		}
		
		Write-Host "Service path searched: $serviceConfigFolder"
		
		if (Test-Path $serviceConfigFolder) {
            # Check if the folder is empty
            if ((Get-ChildItem $serviceConfigFolder | Measure-Object).Count -eq 0) {
                # Delete the empty folder
                Remove-Item $serviceConfigFolder -Recurse -Force
                Write-Host "Empty $serviceConfigFolder deleted."
            } else {
                Write-Host "Striim service configuration found in $serviceConfigFolder. It is not empty, so it will not be deleted."
            }
        } 

        if (-not (Test-Path $serviceConfigFolder)) {
            # Find Striim version
            $platformJar = Get-ChildItem $striimInstallPath\lib -Filter "Platform-*.jar" | Select-Object -First 1
            if ($platformJar) {
                $versionMatch = $platformJar.Name -match "Platform-(.*)\.jar"
                if ($versionMatch) {
                    $striimVersion = $matches[1]

                    # Download and extract service/agent file
                    $downloadUrl = if ($nodeType -eq "A") {
                        "https://striim-downloads.striim.com/Releases/$striimVersion/Striim_windowsAgent_$striimVersion.zip"
                    } else {
                        "https://striim-downloads.striim.com/Releases/$striimVersion/Striim_windowsService_$striimVersion.zip"
                    }

					[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
                    
					$downloadPath = $downloadDir + "\" + $downloadUrl.Split("/")[-1]
                    Invoke-WebRequest -Uri $downloadUrl -OutFile $downloadPath
                    
					# Extract to a temporary directory to avoid nested folders
					$tempExtractPath = Join-Path $env:TEMP ([Guid]::NewGuid().ToString())
					Expand-Archive -Path $downloadPath -DestinationPath $tempExtractPath

					# Move the contents of the extracted folder to the desired location
					$extractedContent = Get-ChildItem $tempExtractPath
					Move-Item $extractedContent.FullName -Destination $serviceConfigFolder -Force

					# Clean up temporary directory and downloaded ZIP
					Remove-Item $tempExtractPath -Recurse -Force
					Remove-Item $downloadPath -Force

                } else {
                    Write-Host "Could not determine Striim version from Platform jar file."
                }
            } else {
                Write-Host "Could not find Platform jar file in $striimInstallPath\lib to determine Striim version."
            }
        } else {
            Write-Host "Striim service configuration found in $serviceConfigFolder"
        }
		
		# Ask if user wants to set up the service
		$setupService = Read-Host "Do you want to set up the Striim service now? (Y/N)"
		if ($setupService.ToUpper() -eq "Y") {
			# Execute setup script (assuming it's in the extracted folder)
			$output = & $serviceConfigFolder\setupWindowsAgent.ps1
			Write-Host $output
		}
    }
	Write-Host "Note: If your Striim service is using Integrated Security, you may need to change the user the service runs as."
}
