# frozen_string_literal: true

module Admin
  # Manages tenant-level settings: company name, logo, and primary brand color.
  # Only accessible by admin users.
  class SettingsController < BaseController
    # GET /admin/settings
    def edit
      @company = current_company
    end

    # PATCH /admin/settings
    def update
      @company = current_company

      if @company.update(settings_params)
        redirect_to edit_admin_settings_path, notice: "Settings have been updated."
      else
        render :edit, status: :unprocessable_entity
      end
    end

    # DELETE /admin/settings/logo
    def destroy_logo
      @company = current_company

      if @company.logo.attached?
        @company.logo.purge
        redirect_to edit_admin_settings_path, notice: "Logo has been removed."
      else
        redirect_to edit_admin_settings_path, alert: "No logo to remove."
      end
    end

    private

    def settings_params
      params.require(:company).permit(:name, :primary_color, :logo)
    end
  end
end
