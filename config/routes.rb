Rails.application.routes.draw do
  root "listings#index"
  resource :session, only: %i[new create destroy]
  resource :registration, only: %i[new create]
  resources :passwords, param: :token, only: %i[new create edit update]
  resources :listings
  get "my-listings", to: "listings#mine", as: :my_listings
  get "up" => "rails/health#show", as: :rails_health_check
end
