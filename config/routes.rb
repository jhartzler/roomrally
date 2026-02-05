Rails.application.routes.draw do
  # Static pages
  get "privacy", to: "pages#privacy", as: :privacy
  get "terms", to: "pages#terms", as: :terms

  resources :prompt_packs
  resources :trivia_packs
  get "dashboard", to: "dashboard#index", as: :dashboard
  get "customize", to: "customize#index", as: :customize
  get "dev/testing", to: "dev_testing#index"
  post "dev/testing/create_test_game", to: "dev_testing#create_test_game"
  get "dev/testing/show_test_game/:id", to: "dev_testing#show_test_game", as: :show_test_game
  get "dev/testing/set_player_session/:id", to: "dev_testing#set_player_session", as: :set_player_session
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  # Defines the root path route ("/")
  root "pages#landing"
  get "play", to: "home#index"

  resources :rooms, only: %i[create show], param: :code do
    resource :stage, only: :show
    resource :hand, only: :show
    resource :backstage, only: :show
    member do
      post :start_game
      post :claim_host
      post :reassign_host
    end
  end

  get "/rooms/:code/join", to: "players#new", as: :join_room
  resources :players, only: [ :create, :destroy ]
  resources :responses, only: [ :update ] do
    resources :rejections, only: [ :create, :new ]
  end
  resources :votes, only: [ :create ]
  resources :trivia_answers, only: [ :create ]
  resources :speed_trivia_games, only: [] do
    scope module: :speed_trivia do
      resource :question, only: :create
      resource :round_closure, only: :create
      resource :advancement, only: :create
      resource :game_start, only: :create
    end
  end

  resources :write_and_vote_games, only: [] do
    scope module: :write_and_vote do
      resource :game_start, only: :create
    end
  end

  get "/auth/:provider/callback", to: "sessions#omniauth"
  get "/auth/failure", to: redirect("/")
  delete "/logout", to: "sessions#destroy", as: :logout

  mount ActionCable.server => "/cable"

  match "/404", to: "errors#not_found", via: :all
  match "/500", to: "errors#internal_server_error", via: :all
  match "/422", to: "errors#unprocessable_entity", via: :all
  match "*unmatched", to: "errors#not_found", via: :all
end
