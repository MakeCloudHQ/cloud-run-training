# ============================================================================
# Folder Resources
# ============================================================================

# Create folders for each environment using the Google folders module
module "folders" {
  source  = "terraform-google-modules/folders/google"
  version = "~> 4.0"

  parent = var.parent

  names = [
    "Development",
    "Staging",
    "Production"
  ]
}

# Create a map to easily reference folders by environment
locals {
  folder_ids = {
    dev   = module.folders.ids_list[0]  # Development folder
    stage = module.folders.ids_list[1]  # Staging folder
    prod  = module.folders.ids_list[2]  # Production folder
  }
}
