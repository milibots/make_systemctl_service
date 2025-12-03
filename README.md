# make_systemctl_service 🚀

**Automated Systemd Service Generator for Python Projects**

A smart, interactive script that automatically creates systemd services for any Python application with virtual environment detection, dependency installation, and full configuration options.

## ✨ Features

- 🔍 **Smart Python file detection** - Automatically finds and identifies main application files
- 🐍 **Virtual Environment Support** - Detects existing venvs or creates new ones
- 📦 **Auto Dependency Installation** - Supports multiple requirement file formats
- ⚙️ **Fully Interactive** - Guided setup with smart defaults
- 🛡️ **Production Ready** - Configures proper systemd service with restart policies
- 📊 **Logging Setup** - Automatic journalctl logging configuration
- 🔧 **Customizable** - Set environment variables, Python arguments, and more

## 🚀 Quick Install & Usage

### Option 1: Direct Installation (Recommended)
```bash
# Run the generator (requires sudo)
bash <(curl -fsSL https://raw.githubusercontent.com/milibots/make_systemctl_service/main/generate.sh)
```

### Option 2: Download & Run Locally
```bash
# Download the script
wget https://raw.githubusercontent.com/milibots/make_systemctl_service/main/generate.sh

# Make executable
chmod +x generate.sh

# Run in your project directory
sudo ./generate.sh
```

## 📋 What the Script Does

1. **Scans your project** for Python files and lets you choose which one to run
2. **Detects virtual environments** (venv, .venv, env, .env, virtualenv)
3. **Installs dependencies** from requirements.txt, pyproject.toml, or other supported files
4. **Creates systemd service** with proper configuration
5. **Sets up automatic restarts** on failure
6. **Configures logging** to journalctl
7. **Enables service** to start on boot
8. **Optionally starts** the service immediately

## 🎯 Interactive Setup

The script guides you through:

```
1. Select Python file to run
2. Choose virtual environment (use existing or create new)
3. Install dependencies (optional)
4. Set service name (auto-generated from filename)
5. Configure user to run service
6. Add Python arguments (e.g., -u for unbuffered)
7. Set environment variables (optional)
8. Start service immediately (optional)
```

## 📁 Supported Project Structures

Works with any Python project:
- Single-file scripts
- Django/Flask applications
- Telegram/Discord bots
- Background workers
- APIs and web services
- Data processing pipelines

## 🔧 Service Management Commands

Once installed, manage your service with:

```bash
# Start service
sudo systemctl start your-service-name

# Stop service
sudo systemctl stop your-service-name

# Restart service
sudo systemctl restart your-service-name

# Check status
sudo systemctl status your-service-name

# View logs in real-time
sudo journalctl -u your-service-name -f

# View all logs
sudo journalctl -u your-service-name

# Enable on boot
sudo systemctl enable your-service-name

# Disable on boot
sudo systemctl disable your-service-name
```

## 📦 Supported Dependency Files

The script automatically detects and installs from:
- `requirements.txt`
- `requirements-dev.txt`
- `pyproject.toml`
- `setup.py`
- `Pipfile` (requires pipenv)

## 🔍 Virtual Environment Detection

Automatically finds virtual environments named:
- `venv/`
- `.venv/`
- `env/`
- `.env/`
- `virtualenv/`

## 🎪 Examples

### Create service for a Telegram bot:
```bash
cd ~/my-telegram-bot
bash <(curl -fsSL https://raw.githubusercontent.com/milibots/make_systemctl_service/main/generate.sh)
```

### Create service for a Flask web app:
```bash
cd /var/www/my-flask-app
bash <(curl -fsSL https://raw.githubusercontent.com/milibots/make_systemctl_service/main/generate.sh)
```

### Create service for a background worker:
```bash
cd ~/my-background-worker
bash <(curl -fsSL https://raw.githubusercontent.com/milibots/make_systemctl_service/main/generate.sh)
```

## ⚙️ Advanced Configuration

### Custom Python Arguments:
When prompted, you can add Python arguments like:
- `-u` for unbuffered output (recommended for logging)
- `-O` for optimized mode
- `-W ignore` to suppress warnings

### Environment Variables:
Set environment variables during setup:
```
DATABASE_URL=postgresql://user:pass@localhost/db
API_KEY=your-secret-key
DEBUG=false
```

## 🐛 Troubleshooting

### "No Python files found"
- Ensure you're in the correct project directory
- Make sure your Python files have `.py` extension
- Check file permissions

### "Permission denied"
- Run with sudo or as root user
- Ensure you have write access to `/etc/systemd/system/`

### Service fails to start
```bash
# Check error logs
sudo journalctl -u your-service-name -f

# Check service status
sudo systemctl status your-service-name

# Test manually
cd /path/to/project
python3 your-script.py
```

### Virtual environment issues
```bash
# Recreate virtual environment
rm -rf venv
python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt
```

## 📁 Generated Files

- **Service file:** `/etc/systemd/system/your-service-name.service`
- **Working directory:** Your project directory
- **Logs:** System journal (`journalctl -u your-service-name`)

## 🔒 Security Notes

- The script requires `sudo` to create systemd services
- Review the script before running (it's open source!)
- Environment variables are stored in the service file (readable by root)
- Use strong passwords for database connections in environment variables

## 🤝 Contributing

Found a bug or have a feature request?
1. Open an issue on GitHub
2. Submit a pull request
3. Suggest improvements

## 📄 License

MIT License - Free to use, modify, and distribute.

## ❓ FAQ

**Q: Can I use this for non-Python applications?**  
A: Currently designed for Python, but can be modified for other languages.

**Q: Does it work on all Linux distributions?**  
A: Works on any system with systemd (Ubuntu 16.04+, Debian 8+, CentOS 7+, etc.)

**Q: Can I run multiple instances of the same script?**  
A: Yes, give them different service names.

**Q: How do I update the service configuration?**  
A: Re-run the script - it will detect and offer to overwrite existing services.

**Q: What if my script needs specific Python version?**  
A: Use a virtual environment with the required Python version before running the script.

---

**🚀 Get Started Now:**
```bash
bash <(curl -fsSL https://raw.githubusercontent.com/milibots/make_systemctl_service/main/generate.sh)
```

**💡 Pro Tip:** Always test your script manually before setting it up as a service!
