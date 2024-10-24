# Define default values
$striimInstallPath = Get-Location
$downloadDir = -join ($striimInstallPath, "\downloads")

# Step 1: Create downloads folder if it doesn't exist
if (-not (Test-Path $downloadDir)) {
    New-Item -ItemType Directory -Force -Path $downloadDir
}

# Step 2: Check for agent.conf or startUp.properties to determine node type
$agentConfPath = -join ($striimInstallPath, "\conf\agent.conf")
$startUpPropsPath = -join ($striimInstallPath, "\conf\startUp.properties")

if (Test-Path $agentConfPath) {
    $nodeType = "A"  # Agent
    Write-Host "[Envrnmt]       -> AGENT Environment based on agent.conf"
} elseif (Test-Path $startUpPropsPath) {
    $nodeType = "N"  # Node
    Write-Host "[Envrnmt]       -> NODE environment based on startUp.properties"
} else {
    # If neither file is found, ask the user
    $nodeType = Read-Host "[Envrnmt]  Is this Agent (default) or Node? (Enter 'A' for Agent or 'N' for Node)"
    if ($nodeType -eq "") { $nodeType = "A" }
    $nodeType = $nodeType.ToUpper()
}

# Ask user for Striim install path only if node type couldn't be auto-detected
if ($nodeType -eq "") {
    $striimInstallPathInput = Read-Host "[Envrnmt] Provide Striim install path or press Enter to default to $($striimInstallPath):"
    if ($striimInstallPathInput -ne "") {
        $striimInstallPath = $striimInstallPathInput
    }
    Write-Host "[Envrnmt] Success: User set Striim Install Path set to: $striimInstallPath"
} else {
	Write-Host "[Envrnmt] Success: Striim Install Path set to: $striimInstallPath"
}

# Agent-specific checks
if ($nodeType -eq "A") {
	Write-Host "[Config ]       -> AGENT -> Specific Tests for configuration:"
    $agentConfPath = -join ($striimInstallPath, "\conf\agent.conf")

    # Check if agent.conf exists
    if (Test-Path $agentConfPath) {
        $agentConfLines = Get-Content $agentConfPath

        $clusterNameFound = $false
        $serverNodeAddressFound = $false

        foreach ($line in $agentConfLines) {
            # Check for striim.cluster.clusterName with a non-empty value
            if ($line -match "striim\.cluster\.clusterName\s*=\s*(.*)") {
                $clusterNameValue = $matches[1]
                if ($clusterNameValue -ne "") {
                    Write-Host "[Config ] Success: 'striim.cluster.clusterName' found in agent.conf with value: $clusterNameValue"
                    $clusterNameFound = $true
                } else {
                    Write-Host "[Config ] Fail***: 'striim.cluster.clusterName' found in agent.conf but has no value. Please provide a value."
                }
            }

            # Check for striim.node.servernode.address with a non-empty value
            if ($line -match "striim\.node\.servernode\.address\s*=\s*(.*)") {
                $serverNodeAddressValue = $matches[1]
                if ($serverNodeAddressValue -ne "") {
                    Write-Host "[Config ] Success: 'striim.node.servernode.address' found in agent.conf with value: $serverNodeAddressValue"
                    $serverNodeAddressFound = $true
                } else {
                    Write-Host "[Config ] Fail***: 'striim.node.servernode.address' found in agent.conf but has no value. Please provide a value."
                }
            }
        }

        # Check if properties were found at all
        if (-not $clusterNameFound) {
            Write-Host "[Config ] Fail***: 'striim.cluster.clusterName' not found in agent.conf. Please provide a value."
        }
        if (-not $serverNodeAddressFound) {
            Write-Host "[Config ] Fail***: 'striim.node.servernode.address' not found in agent.conf. Please provide a value."
        }
    } else {
        Write-Host "[Config ] Fail***: agent.conf not found in $($striimInstallPath)\conf"
    }
}

# Node-specific checks
if ($nodeType -eq "N") {
	Write-Host "[Config ]       -> NODE -> Specific Tests for configuration:"
    $startUpPropsPath = -join ($striimInstallPath, "\conf\startUp.properties")

    # Check if startUp.properties exists
    if (Test-Path $startUpPropsPath) {
        $startUpPropsLines = Get-Content $startUpPropsPath

        $requiredProps = "CompanyName", "LicenceKey", "ProductKey", "WAClusterName"
        $propsFound = @{}  # Dictionary to track found properties
        foreach ($prop in $requiredProps) {
            $propsFound[$prop] = $false
        }

        foreach ($line in $startUpPropsLines) {
            foreach ($prop in $requiredProps) {
                if ($line -match "$prop\s*=\s*(.*)") {
                    $propValue = $matches[1]
                    if ($propValue -ne "") {
                        Write-Host "[Config ] Success: '$prop' found in startUp.properties with value: $propValue"
                        $propsFound[$prop] = $true
                    } else {
                        Write-Host "[Config ] Fail***: '$prop' found in startUp.properties but has no value. Please provide a value."
                    }
                    break  # Exit the inner loop once a property is found on a line
                }
            }
        }

        # Check if all required properties were found
        foreach ($prop in $requiredProps) {
            if (-not $propsFound[$prop]) {
                Write-Host "[Config ] Fail***: '$prop' not found in startUp.properties. Please provide a value."
            }
        }
    } else {
        Write-Host "[Config ] Fail***: startUp.properties not found in $($striimInstallPath)\conf"
    }
}

# Check if Striim lib directory is in PATH
$striimLibPath = -join ($striimInstallPath, "\lib")
Write-Host "[Config ]       -> Striim Lib Path set to: $striimLibPath"
if ($env:Path -split ";" -contains $striimLibPath) {
    Write-Host "[Config ] Success: Striim lib directory found in PATH."
} else {
    Write-Host "[Config ] Fail***: Striim lib directory not found in PATH."
	$addToPathChoice = Read-Host "[Config ]  Do you want to add it to the system PATH? (Y/N)"
    if ($addToPathChoice.ToUpper() -eq "Y") {
        # Add Striim lib directory to PATH
        $newPath = $env:Path + ";" + $striimLibPath
        [Environment]::SetEnvironmentVariable("Path", $newPath, "Machine") # Set for all users
        
        # Refresh the current session's environment variables
        $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine")

        Write-Host "[Config ] Success: Striim lib directory added to PATH."
    }
}

# Check for required DLLs
$requiredDlls = "icudt72.dll", "icuuc72.dll", "MSSQLNative.dll"
foreach ($dll in $requiredDlls) {
    if (Test-Path "$striimLibPath\$dll") {
        Write-Host "[DLLs   ] Success: $dll found in $striimLibPath"
    } else {
        # Offer to download DLLs
        $downloadChoice = Read-Host "[DLLs   ]  $striimLibPath\$dll not found. Download it? (Y/N)"
        if ($downloadChoice.ToUpper() -eq "Y") {
            # Create download directory if it doesn't exist
            if (-not (Test-Path $downloadDir)) {
                New-Item -ItemType Directory -Force -Path $downloadDir
            }

            if ($dll -eq "MSSQLNative.dll") {
                $downloadUrl = "https://github.com/daniel-striim/StriimQueryAutoLoader/raw/refs/heads/main/MSJet/FixesFor4.2.0.20/MSSQLNative.dll"
            } else {
                $downloadUrl = "https://github.com/daniel-striim/StriimQueryAutoLoader/raw/refs/heads/main/MSJet/FixesFor4.2.0.20/Dlls.zip"
            }

			$finalPath = -join ($striimLibPath, "\Dlls\", $dll)

			if (-not (Test-Path $finalPath)) {

				$downloadPath = -join ($downloadDir,  "\", $downloadUrl.Split("/")[-1])
				Invoke-WebRequest -Uri $downloadUrl -OutFile $downloadPath

				if ($downloadUrl.EndsWith(".zip")) {
					Expand-Archive -Path $downloadPath -DestinationPath $striimLibPath -Force
					Copy-Item $finalPath $striimLibPath
					Remove-Item $finalPath -Force
				} else {
					Copy-Item $downloadPath $striimLibPath
					Remove-Item $downloadPath -Force
				}
			} else {
				Copy-Item $finalPath $striimLibPath
				Remove-Item $finalPath -Force
			}

            Write-Host "[DLLs   ] Success: $dll downloaded and extracted to $striimLibPath"
        }
    }
}

$tempFolders = "$striimLibPath\__MACOSX", "$striimLibPath\Dlls"
foreach ($folder in $tempFolders) {
	if (Test-Path $folder) {
		Remove-Item $folder -Recurse -Force
		Write-Host "[Cleanup] Success: Deleted temporary folder: $folder"
	}
}

# Determine Java Version
if (Get-Command java -ErrorAction SilentlyContinue) {
    $javaVersionOutput = java -version 2>&1 | Select-String -Pattern 'java version "(.*)"'
	Write-Host "[Java   ] Success: Java version: $javaVersionOutput"
    if ($javaVersionOutput) {
        $javaVersion = $javaVersionOutput.Matches.Groups[1].Value
        if ($javaVersion -match "1\.8" -or $javaVersion -match "18\.0\.\d+\.\d+") {
            Write-Host "[Java   ] Success: Java 8 found."
        } else {
            # Offer to download Java 8
            $downloadJavaChoice = Read-Host "  Java 8 not found. Download it? (Y/N)"
            if ($downloadJavaChoice.ToUpper() -eq "Y") {
                $javaDownloadUrl = "https://builds.openlogic.com/downloadJDK/openlogic-openjdk/8u422-b05/openlogic-openjdk-8u422-b05-windows-x64.msi"
                $javaDownloadPath = -join ($downloadDir,  "\", $javaDownloadUrl.Split("/")[-1])
                Invoke-WebRequest -Uri $javaDownloadUrl -OutFile $javaDownloadPath
                Write-Host "[Java   ] Success: Java 8 installer downloaded to $javaDownloadPath. Please install it."
            }
        }
    } else {
        Write-Host "[Java   ] Fail***: Could not determine Java version."
    }
} else {
    # Offer to download Java 8
    $downloadJavaChoice = Read-Host "[Java   ] Java not found. Download Java 8? (Y/N)"
    if ($downloadJavaChoice.ToUpper() -eq "Y") {
        $javaDownloadUrl = "https://builds.openlogic.com/downloadJDK/openlogic-openjdk/8u422-b05/openlogic-openjdk-8u422-b05-windows-x64.msi"
        $javaDownloadPath = -join ($downloadDir, "\", $javaDownloadUrl.Split("/")[-1])
        Invoke-WebRequest -Uri $javaDownloadUrl -OutFile $javaDownloadPath
        Write-Host "[Java   ] Fail***: Java 8 installer downloaded to $javaDownloadPath. Please install it."
    }
}

# Determine if Integrated Security is needed
$sqljdbcAuthDllPath = "C:\Windows\System32\sqljdbc_auth.dll"
if (Test-Path $sqljdbcAuthDllPath) {
    Write-Host "[Int Sec] Success: Integrated Security: sqljdbc_auth.dll found in C:\Windows\System32"
} else {
    # Ask about Integrated Security only if the DLL is missing
    $useIntegratedSecurity = Read-Host "[Int Sec] Plan to use Integrated Security? (Y/N)"
    if ($useIntegratedSecurity.ToUpper() -eq "Y") {
        # Check if it exists in /lib
        if (Test-Path "$striimLibPath\sqljdbc_auth.dll") {
            $copyChoice = Read-Host "[Int Sec] Integrated Security:  sqljdbc_auth.dll found in $striimLibPath. Copy it to C:\Windows\System32? (Y/N)"
            if ($copyChoice.ToUpper() -eq "Y") {
                Copy-Item "$striimLibPath\sqljdbc_auth.dll" $sqljdbcAuthDllPath
                Write-Host "[Int Sec] Success: Integrated Security: sqljdbc_auth.dll copied to C:\Windows\System32"
            }
        } else {
            # Offer to download
            $downloadChoice = Read-Host "[Int Sec] Integrated Security:  sqljdbc_auth.dll not found. Download it? (Y/N)"
            if ($downloadChoice.ToUpper() -eq "Y") {
                $downloadUrl = "https://github.com/daniel-striim/StriimQueryAutoLoader/raw/main/MSJet/sqljdbc_auth.dll" # Update with the correct URL if needed
                $downloadPath = -join ($downloadDir, "\", $downloadUrl.Split("/")[-1])
                Invoke-WebRequest -Uri $downloadUrl -OutFile $downloadPath
                Copy-Item $downloadPath $sqljdbcAuthDllPath
                Write-Host "[Int Sec] Success: Integrated Security: sqljdbc_auth.dll downloaded and copied to C:\Windows\System32"
            }
        }
    }
}

# Define the file paths and URLs
$files = @(
    @{
        Name = 'Platform-4.2.0.20.jar'
	OName = 'Platform_48036_v4.2.0.20_27_Sep_2024.jar'
        Url = 'https://github.com/daniel-striim/StriimQueryAutoLoader/raw/refs/heads/main/MSJet/FixesFor4.2.0.20/Platform_48036_v4.2.0.20_27_Sep_2024.jar'
    },
    @{
        Name = 'MSJet-4.2.0.20.jar'
	OName = 'MSJet_48036_v4.2.0.20_27_Sep_2024.jar'
        Url = 'https://github.com/daniel-striim/StriimQueryAutoLoader/raw/refs/heads/main/MSJet/FixesFor4.2.0.20/MSJet_48036_v4.2.0.20_27_Sep_2024.jar'
    },
    @{
        Name = 'SourceCommons-4.2.0.20.jar'
	OName = 'SourceCommons_48036_v4.2.0.20_27_Sep_2024.jar'
        Url = 'https://github.com/daniel-striim/StriimQueryAutoLoader/raw/refs/heads/main/MSJet/FixesFor4.2.0.20/SourceCommons_48036_v4.2.0.20_27_Sep_2024.jar'
    }
)

# Check if the files exist in the specified directory
$filesExist = $files | ForEach-Object {
    Test-Path (Join-Path $striimLibPath $_.Name)
}

# If any of the files exist, prompt the user
if ($filesExist -contains $true) {
    $response = Read-Host -Prompt "The specified directory contains files that may require patching. Do you want to install the patches? (y/n)"

    if ($response -eq 'y') {
        # Download and replace the files
        $files | ForEach-Object {
            Invoke-WebRequest $_.Url -OutFile (Join-Path $striimLibPath $_.OName)
            Remove-Item (Join-Path $striimLibPath $_.Name.Replace('_48036', '')) -Force
        }

        # Download and replace MSSQLNative.dll
        Invoke-WebRequest 'https://github.com/daniel-striim/StriimQueryAutoLoader/raw/refs/heads/main/MSJet/FixesFor4.2.0.20/MSSQLNative.dll' -OutFile (Join-Path $striimLibPath 'MSSQLNative.dll')

        Write-Host "Patches installed successfully."
    } else {
        Write-Host "Patching skipped."
    }
} else {
    Write-Host "No files found that require patching."
}

# Check Software Requirements
Write-Host "[Softwre] Success: Checking for installed requirements..."

# Get the list of installed software once
$installedSoftwareList = Get-WmiObject -Class Win32_Product

Write-Host "[Softwre] Success: Checking for installed requirements...Software list gathered."

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
                Write-Host "[Softwre] Success: $($software.Name) version $($software.Version) found. Meets requirement."
            } else {
                Write-Host "[Softwre] Fail***: $($software.Name) version $($software.Version) found, but it's too old."
                DownloadAndInstallSoftware $softwareName $downloadUrl
            }
        }
    } else {
        Write-Host "[Softwre] Fail***: $softwareName not found."
        DownloadAndInstallSoftware $softwareName $downloadUrl
    }
}

# Function to download and provide instructions for software installation
function DownloadAndInstallSoftware {
    param(
        [string]$softwareName,
        [string]$downloadUrl
    )

    $downloadChoice = Read-Host "[Softwre]  Do you want to download and install $softwareName? (Y/N)"
    if ($downloadChoice.ToUpper() -eq "Y") {
		[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

		# Resolve the redirection link to get the actual download URL
		if ($downloadUrl -eq "https://aka.ms/vs/16/release/14.29.30133/VC_Redist.x64.exe") {
			$downloadPath = -join ($downloadDir, "\VC_Redist.x64.exe" )
		} else {
			$downloadPath = -join ($downloadDir, "\msoledbsql.msi" )
		}
		Write-Host "[Softwre] downloadPath $downloadPath"
        $response = Invoke-WebRequest -Uri $downloadUrl -MaximumRedirection 5 -OutFile $downloadPath # Allow up to 5 redirections
		
		Write-Host "[Softwre] downloadUrl $downloadUrl"

        Write-Host "[Softwre] Success: $softwareName installer downloaded to $downloadPath. Please run it to install."
    }
}

# Check for Microsoft Visual C++ 2015-2019 Redistributable
CheckAndDownloadSoftware "Microsoft Visual C++ 2019 X64 Minimum Runtime" "14.28.29914" "https://aka.ms/vs/16/release/14.29.30133/VC_Redist.x64.exe"

# Check for Microsoft OLE DB Driver for SQL Server
CheckAndDownloadSoftware "Microsoft OLE DB Driver for SQL Server" "18.2.3.0" "https://go.microsoft.com/fwlink/?linkid=2119554"

# Check for fixes for 4.2.0.20

# Check if Striim service is installed
if ($nodeType -eq "A") {
	$serviceName = "Striim Agent"
} else {
	$serviceName = "Striim"
}
if (Get-Service $serviceName -ErrorAction SilentlyContinue) {
        Write-Host "[Service] Success: Striim service is installed."
		Write-Host "[Service] * Note : If your Striim service is using Integrated Security, you may need to change the user the service runs as."
} else {
	$runAsService = Read-Host "[Service] Plan to run Striim as a service? (Y/N)"
	if ($runAsService.ToUpper() -eq "Y") {
	
		# Check for windowsService/windowsAgent folder
		if ($nodeType -eq "A") {
			$serviceConfigFolder = -join ($striimInstallPath, "\conf\windowsAgent")
		} else {
			$serviceConfigFolder = -join ($striimInstallPath, "\conf\windowsService")
		}

		Write-Host "[Service] Service path searched: $serviceConfigFolder"

		if (Test-Path $serviceConfigFolder) {
			# Check if the folder is empty
			if ((Get-ChildItem $serviceConfigFolder | Measure-Object).Count -eq 0) {
				# Delete the empty folder
				Remove-Item $serviceConfigFolder -Recurse -Force
				Write-Host "[Service] Success Empty $serviceConfigFolder deleted."
			} else {
				Write-Host "[Service] Success: Striim service configuration found in $serviceConfigFolder. It is not empty, so it will not be deleted."
			}
		}

		if (-not (Test-Path $serviceConfigFolder)) {
			# Find Striim version
			$platformJar = Get-ChildItem $striimInstallPath\lib -Filter "DatabaseReader-*.jar" | Select-Object -First 1
			if ($platformJar) {
				$versionMatch = $platformJar.Name -match "DatabaseReader-(.*)\.jar"
				if ($versionMatch) {
					$striimVersion = $matches[1]

					# Download and extract service/agent file
					$downloadUrl = if ($nodeType -eq "A") {
						"https://striim-downloads.striim.com/Releases/$striimVersion/Striim_windowsAgent_$striimVersion.zip"
					} else {
						"https://striim-downloads.striim.com/Releases/$striimVersion/Striim_windowsService_$striimVersion.zip"
					}

					[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

					$downloadPath = -join ($downloadDir, "\", $downloadUrl.Split("/")[-1])
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
					Write-Host "[Service] Fail***: Could not determine Striim version from Platform jar file."
				}
			} else {
				Write-Host "[Service] Fail***: Could not find Platform jar file in $striimInstallPath\lib to determine Striim version."
			}
		} else {
			Write-Host "[Service] Fail***: Striim service configuration found in $serviceConfigFolder"
		}

		# Ask if user wants to set up the service
		$setupService = Read-Host "[Service]  Do you want to set up the Striim service now? (Y/N)"
		if ($setupService.ToUpper() -eq "Y") {
			# Execute setup script (assuming it's in the extracted folder)
			if ($nodeType -eq "A") {
				$setupScriptPath = Join-Path $serviceConfigFolder "setupWindowsAgent.ps1"
			} else {
				$setupScriptPath = Join-Path $serviceConfigFolder "setupWindowsService.ps1"
			}
			
			
			Write-Host "[Service] Run the service setup located here: $setupScriptPath"
		}

		Write-Host "[Service] * Note : If your Striim service is using Integrated Security, you may need to change the user the service runs as."
	}
}
