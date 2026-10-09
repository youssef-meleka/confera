Rails.application.routes.draw do
  get "up" => "rails/health#show", as: :rails_health_check

  namespace :api do
    namespace :v1 do
      resources :users, only: [:create]

      post   "sessions",         to: "sessions#create"
      delete "sessions/current", to: "sessions#destroy"

      resources :conferences
      resources :registrations, only: [:index, :create]
    end
  end
end