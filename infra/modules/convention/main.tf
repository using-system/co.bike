locals {
  resource_name = join(var.delimiter, [
    var.project,
    var.environment,
    var.region
  ])

  resource_name_without_delimiter = join("", [
    var.project,
    var.environment,
    var.region
  ])
}
