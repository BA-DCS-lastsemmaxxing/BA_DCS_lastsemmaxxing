terraform {
  backend "remote" {
    organization = "lsm-fyp"

    workspaces {
      name = "BA_DCS_lastsemmaxxing"
    }
  }
}
