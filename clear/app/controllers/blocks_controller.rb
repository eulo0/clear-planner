class BlocksController < ApplicationController
  before_action :authenticate_user!
  before_action :set_block, only: %i[update destroy reschedule]

  def index
    @proposed = current_user.blocks.proposed.order(:position, :id)
    @active   = current_user.blocks.active.order(:position, :id)
    @blocks   = @proposed.any? ? @proposed : @active
    @mode     = @proposed.any? ? "proposed" : "active"
  end

  def create
    block = current_user.blocks.new(block_params)
    if block.save
      redirect_to blocks_path, notice: "Block added."
    else
      redirect_to blocks_path, alert: block.errors.full_messages.to_sentence
    end
  end

  def update
    if @block.update(block_params)
      redirect_to blocks_path, notice: "Block updated."
    else
      redirect_to blocks_path, alert: @block.errors.full_messages.to_sentence
    end
  end

  def destroy
    @block.destroy
    redirect_to blocks_path, notice: "Block removed."
  end

  def reschedule
    @block.update!(
      start_minute: params[:start_minute].to_i,
      end_minute:   params[:end_minute].to_i,
      repeat_days:  params[:repeat_days].present? ? Array(params[:repeat_days]).map(&:to_i) : @block.repeat_days
    )
    head :ok
  rescue ActiveRecord::RecordInvalid => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  def accept
    current_user.blocks.proposed.update_all(status: "active")
    redirect_to dashboard_path, notice: "Routine saved."
  end

  def discard_proposed
    current_user.blocks.proposed.delete_all
    redirect_to blocks_path, notice: "Proposed routine discarded."
  end

  private

  def set_block
    @block = current_user.blocks.find(params[:id])
  end

  def block_params
    params.require(:block).permit(:label, :color, :start_minute, :end_minute, :status, repeat_days: [])
  end
end
