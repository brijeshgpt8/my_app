class CountersController < ApplicationController
  skip_before_action :verify_authenticity_token
  # GET /counters
  # GET /counters.json
  def index
    @counter = Counter.first
    if @counter.try(:count).blank?
      @counter = Counter.create(count: 10)
    else
      @counter.update_attributes(count: (@counter.count + 1))
    end
    render json: @counter.count
  end

  # POST /counters
  # POST /counters.json
  def create
    @counter = Counter.first
    @counter.update_attributes(count: (@counter.count + 2))
    render json: @counter.count
  end

  # DELETE /counters/1
  # DELETE /counters/1.json
  def destroy
    @counter = Counter.first
    @counter.update_attributes(count: (@counter.count - 1))
    render json: @counter.count
  end
end
