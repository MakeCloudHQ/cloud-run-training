# Pre-Session Setup Instructions

Please complete these setup steps **before** the training session to ensure we can make the most of our time together.

## 1. Google Cloud Platform Access

You should have received:
- Access to a GCP project in your organization
- **Owner** role permissions on this project
- The project should be linked to a billing account

### Verify Your Access

1. Go to [Google Cloud Console](https://console.cloud.google.com)
2. Check you can see the training project in the project selector
3. Navigate to **IAM & Admin** > **IAM** to verify you have Owner role

If you don't have access, please contact your Director of Engineering or the session organizer.

---

## 2. Install Google Cloud CLI

The `gcloud` CLI is essential for interacting with GCP from your terminal.

### macOS
```bash
brew install --cask google-cloud-sdk
```

### Linux
```bash
curl https://sdk.cloud.google.com | bash
exec -l $SHELL
```

### Windows
Download and run the installer from: https://cloud.google.com/sdk/docs/install

### Verify Installation
```bash
gcloud --version
```

You should see output showing the gcloud version (e.g., `Google Cloud SDK 450.0.0`)

---

## 3. Authenticate with gcloud

```bash
# Login with your Google account
gcloud auth login

# Set your default project (replace PROJECT_ID with your training project)
gcloud config set project PROJECT_ID

# Enable application default credentials (needed for some APIs)
gcloud auth application-default login
```

### Verify Authentication
```bash
gcloud auth list
gcloud config list
```

---

## 4. Install Docker Desktop

We'll use Docker to build container images locally.

### macOS
Download from: https://www.docker.com/products/docker-desktop/

### Linux
```bash
# Ubuntu/Debian
sudo apt-get update
sudo apt-get install docker.io docker-compose
sudo usermod -aG docker $USER
```

Log out and back in for group changes to take effect.

### Windows
Download from: https://www.docker.com/products/docker-desktop/

### Verify Installation
```bash
docker --version
docker ps
```

---

## 5. Enable Required APIs

Run these commands to enable the GCP APIs we'll be using:

```bash
gcloud services enable run.googleapis.com
gcloud services enable artifactregistry.googleapis.com
gcloud services enable compute.googleapis.com
gcloud services enable vpcaccess.googleapis.com
```

This may take a minute or two to complete.

---

## 6. Text Editor / IDE

Have your preferred code editor ready. Suggestions:
- VS Code (recommended - has great GCP extensions)
- IntelliJ IDEA
- Sublime Text
- vim/emacs (if you're comfortable with them)

---

## 7. Optional: Install Terraform (for Advanced Section)

If you want to follow along with the Terraform examples in the advanced section:

### macOS
```bash
brew tap hashicorp/tap
brew install hashicorp/tap/terraform
```

### Linux
```bash
wget -O- https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list
sudo apt update && sudo apt install terraform
```

### Windows
Download from: https://www.terraform.io/downloads

### Verify Installation
```bash
terraform --version
```

---

## Troubleshooting

### "gcloud: command not found"
- Make sure you've restarted your terminal after installation
- Check that gcloud is in your PATH: `echo $PATH`

### "You do not currently have an active account selected"
- Run `gcloud auth login` again
- Make sure you're using the correct Google account

### Docker permission denied
- Linux users: Make sure you've added yourself to the docker group and logged out/in
- macOS/Windows: Make sure Docker Desktop is running

### API enablement fails
- Verify your project has billing enabled
- Check you have the necessary IAM permissions (Owner role)

---

## Ready to Go?

If you've completed all the steps above, you're ready for the training session!

See you tomorrow!

## Questions?

If you run into any issues with setup, please reach out before the session so we can troubleshoot.
