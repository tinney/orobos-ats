# frozen_string_literal: true

module Admin
  class OffersController < BaseController
    self._required_roles = [{ role: "hiring_manager" }]

    before_action :set_application
    before_action :set_offer, only: [:edit, :update]

    # POST /admin/applications/:application_id/offers
    def create
      @offer = @application.offers.build(offer_params)
      @offer.company = current_company
      @offer.created_by = current_user

      if @offer.save
        redirect_to admin_application_path(@application), notice: "Offer created."
      else
        redirect_to admin_application_path(@application), alert: @offer.errors.full_messages.join(", ")
      end
    end

    # GET /admin/applications/:application_id/offers/:id/edit
    def edit
    end

    # PATCH /admin/applications/:application_id/offers/:id
    def update
      if @offer.update(offer_params)
        redirect_to admin_application_path(@application), notice: "Offer updated."
      else
        render :edit, status: :unprocessable_entity
      end
    end

    private

    def set_application
      @application = ApplicationSubmission.find(params[:application_id])
    end

    def set_offer
      @offer = @application.offers.find(params[:id])
    end

    def offer_params
      params.require(:offer).permit(:salary, :salary_currency, :start_date, :status, :notes)
    end
  end
end
