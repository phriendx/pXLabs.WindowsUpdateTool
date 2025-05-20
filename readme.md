# pXLabs.WindowsUpdateTool

![PowerShell](https://img.shields.io/badge/PowerShell-blue?logo=powershell) ![Windows](https://img.shields.io/badge/Windows-0078D6?logo=windows) ![License: GPLv3](https://img.shields.io/badge/license-GPLv3-blue)


**pXLabs.WindowsUpdateTool** is a user-friendly, WPF-based PowerShell utility designed to simplify and enhance the management of Windows Updates on local and remote systems. Building upon the robust functionality provided by the widely-used PSWindowsUpdate module, pXLabs.UpdateTool offers an intuitive graphical interface and dynamic workflow to streamline update scanning, installation, and troubleshooting. Built for IT admins, helpdesk teams, and endpoint engineers.

---

## 🚀 Features

- 🎨 **Theme Switching**: Dark, Light, Monokai, Nord, and EverForest themes.
- 🖥️ **Remote Computer Tools**:
  - Ping machine
  - Open Event Viewer, File Explorer, or PowerShell session remotely
  - Check critical services
  - Reset Windows Update components
- 📋 **Update Management**:
  - Scan for updates
  - Evaluate update applicability
  - Install selected updates
  - View update history and settings
- 🛠️ **Policy Management**:
  - Refresh Group Policy (GPO)
  - Fetch Intune policies
  - Refresh Configuration Manager (CM) policies
- ⚙️ **WSUS & Autopatch Support**:
  - Trigger WSUS scans
  - Restart Configuration Manager agent
- 🧾 **Live Output and Status Feedback**:
  - Real-time RichTextBox log viewer
  - DataGrid view for available updates
  - Progress bar and detailed status indicators

---
## Why Use pXLabs.WindowsUpdateTool?

- Save time with one-click update scans, installs, and policy refreshes  
- Simplify remote Windows update tasks with intuitive UI  
- Stay informed with live progress, logs, and update history  
- Easily selectable themes for comfortable daily use  
- Built on trusted PowerShell and Microsoft Graph APIs for enterprise-grade functionality  

---

## ⚡ Quick Start

Get up and running with **pXLabs.WindowsUpdateTool** in just a few easy steps:

1. **Open PowerShell as Administrator.**

2. **Install prerequisite modules (if you haven’t already):**

```powershell
Install-Module -Name PSWindowsUpdate -Scope CurrentUser
Install-Module -Name Microsoft.Graph -Scope CurrentUser
Import-Module -Name pXLabs.WindowsUpdateTool -Scope CurrentUser
```
3. **Import the module and launch the tool:**
```powershell
Import-Module pXLabs.WindowsUpdateTool
Start-WindowsUpdateTool
```
4. **Enter the target computer name (or leave blank for local).**
5. **Use the intuitive GUI to scan, install, and manage Windows Updates.**

---

## 🖼️ UI Layout

- **Menu Bar**: Theme selector
- **Top Panel**: Device entry and admin tool buttons
- **Middle Grid**: 
  - DataGrid for update list with contextual install option
  - Progress bar for task visibility
- **Tabbed Controls**:
  - WSUS actions
  - Microsoft Update queries
  - Policy and CM tools
- **Bottom Panel**: RichTextBox output console
- **Status Bar**: Displays session, update method, and disk info

---

## 🛠 Requirements

- Windows PowerShell 5.1+
- PSWindowsUpdate module
- Microsoft.Graph module (for Intune commands)
- Admin privileges
- Remote Management enabled (for remote functions)
- .NET Framework 4.7.2+

---

## 📦 Graph Prerequisites

### PowerShell Modules

- Microsoft.Graph

```powershell
Install-Module Microsoft.Graph -Scope CurrentUser
```

### Required Permissions (Azure App Registration)

To access Intune data using Microsoft Graph, register an app in Azure AD:

1. Go to [Azure Portal > App registrations](https://portal.azure.com/#blade/Microsoft_AAD_RegisteredApps/ApplicationsListBlade)
2. Register a new app (e.g., `pXLabs-IntuneIntegration`)
3. Note the **Application (client) ID**
4. Go to **Authentication**:
   - Enable **Public Client Flows** by setting **"Allow public client flows" to Yes**
   - Click **Save**
5. Go to **API permissions**:
   - Add the following Microsoft Graph **Delegated** permissions:
     - `DeviceManagementManagedDevices.Read.All`
     - `DeviceManagementConfiguration.Read.All`
     - `Device.Read.All`
   - Click **Grant admin consent**

---

## 🚀 Planned Integrations (Graph API)

- Fetch update history and protection status
- Correlate device group membership, ownership type, and enrollment source

---

## 🔧 How to Use

1. **Launch the Tool** as Administrator.
2. **Enter Computer Name** to connect or manage remotely.
3. Use **Device Tools** to check services or reset components.
4. Scan or evaluate Windows updates using **WSUS** or **MS Update** buttons.
5. Use the **Policy** section to refresh or retrieve endpoint management settings.
6. View logs and progress in the **output box**.

---

## 🧩 Architecture

- **WPF (XAML)** frontend
- **PowerShell backend**
- Modular button handlers triggering various PowerShell scripts
- Context-aware update installer via DataGrid menu

---

## 📸 Screenshots

![Main UI with update list and progress](docs/images/UpdateScreenshot.gif?raw=true)
*Main window showing available updates and real-time progress*

![Theme switching in action](docs/images/ThemesScreenshot.gif?raw=true)
*Easily switch between light and dark themes, plus more styles*

---

## 📝 To Do

- [x] Add logging to file
- [ ] Usage metrics
- [x] Integration with Microsoft Graph API for Intune
- [ ] Export update results to CSV/JSON

---

## 🧪 Testing

- Tested on Windows 10 and 11 (Pro & Enterprise)
- Validated on remote endpoints joined to AD and Intune

---

## 📄 License

## License

This project is licensed under the [GNU General Public License v3.0](https://www.gnu.org/licenses/gpl-3.0.html). Feel free to modify, share, and contribute!

---

## 🙏 Credits

Built by Jeff Pollock at pXLabs  
Inspired by real-world challenges in remote manual Windows Update management.

---
