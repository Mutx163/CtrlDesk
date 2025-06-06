using System.Configuration;
using System.Data;
using System.Windows;
using System.Threading;

namespace PalmControllerServer;

/// <summary>
/// Interaction logic for App.xaml
/// </summary>
public partial class App : System.Windows.Application
{
    private const string AppName = "PalmControllerServer";
    private Mutex? _mutex;

    protected override void OnStartup(StartupEventArgs e)
    {
        _mutex = new Mutex(true, AppName, out bool createdNew);

        if (!createdNew)
        {
            // App is already running, bring the existing instance to the front and exit.
            System.Windows.MessageBox.Show("应用程序已经在运行中。", "提示", MessageBoxButton.OK, MessageBoxImage.Information);
            // Optionally, code to bring the existing window to the front could be added here.
            Shutdown();
            return;
        }

        base.OnStartup(e);
    }

    protected override void OnExit(ExitEventArgs e)
    {
        _mutex?.ReleaseMutex();
        _mutex?.Dispose();
        base.OnExit(e);
    }
}

