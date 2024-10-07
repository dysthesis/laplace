{
  service,
  subdomain,
  prefix ? "/",
}: {
  inherit service;
  rule = "Host(`${subdomain}.dysthesis.com`) && PathPrefix(`${prefix}`)";
  entrypoints = ["websecure"];
  tls = {
    domains = [{main = "*.dysthesis.com";}];
    certresolver = "default";
  };
}
