std = "luajit"
read_globals = { "vim" }

files["spec/"] = {
  std = "+busted",
  globals = { "vim" },
}
