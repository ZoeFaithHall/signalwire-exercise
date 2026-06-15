Rails.application.routes.draw do
  # Liveness probe used by the Docker healthcheck.
  get "up" => "rails/health#show", as: :rails_health_check

  # Authentication (single shared password — single-tenant app).
  get    "login",  to: "sessions#new"
  post   "login",  to: "sessions#create"
  delete "logout", to: "sessions#destroy"

  # First-run onboarding wizard: pick a number, set forwarding.
  get  "onboarding",            to: "onboarding#show",       as: :onboarding
  post "onboarding/search",     to: "onboarding#search",     as: :onboarding_search
  post "onboarding/purchase",   to: "onboarding#purchase",   as: :onboarding_purchase
  post "onboarding/forwarding", to: "onboarding#forwarding", as: :onboarding_forwarding

  # Customer dashboard + the forwarding control it owns.
  get   "dashboard",            to: "dashboard#show",      as: :dashboard
  patch "forwarding",           to: "forwarding#update",   as: :forwarding

  # Admin view: telephony plumbing (inbound-route sync, number management).
  get   "admin",                to: "admin#show",          as: :admin
  post  "webhook/sync",         to: "webhook#sync",        as: :sync_webhook
  post  "phone_number/release", to: "phone_numbers#release", as: :release_phone_number

  # SignalWire inbound-call webhook. Returns SWML. No login, no CSRF; authed by
  # a secret token on the URL (see CallsController). POST only — SignalWire is
  # configured with call_request_method: "POST".
  post "calls/inbound", to: "calls#inbound", as: :inbound_call

  root "dashboard#show"
end
