service: subdomain: {
  inherit service;
  rule = "Host(`${subdomain}.dysthesis.com`) && PathPrefix(`/`)";
  entrypoints = ["websecure"];
  tls = {
    domains = [{main = "*.dysthesis.com";}];
    certresolver = "default";
  };
}
