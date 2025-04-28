terraform {
  backend "remote" {
    organization = "lsm-fyp" # Change this

    workspaces {
      name = "BA_DCS_lastsemmaxxing" # Change this
    }
  }
}
