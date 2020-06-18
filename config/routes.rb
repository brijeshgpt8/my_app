Rails.application.routes.draw do
  resources :counters, :except => ['destroy'], :defaults => { :format => :json }
  delete '/counters' => 'counters#destroy'
end
