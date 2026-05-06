module PackAuthorization
  extend ActiveSupport::Concern

  private

  def set_viewable_pack
    instance_variable_set(pack_ivar_name, pack_model.accessible_by(current_user).find(params[:id]))
  end

  def set_owned_pack
    instance_variable_set(pack_ivar_name, current_user.public_send(pack_ivar_plural).find(params[:id]))
  end

  # Derives e.g. "CategoryPack" from the controller name, then uses it to
  # resolve the model, ivar name, and ownership association.
  #
  #   CategoryPacksController -> CategoryPack -> @category_pack -> current_user.category_packs
  def pack_model
    @pack_model ||= controller_name.classify.constantize
  end

  def pack_ivar_name
    @pack_ivar_name ||= :"@#{pack_model.model_name.param_key}"
  end

  def pack_ivar_plural
    @pack_ivar_plural ||= pack_model.model_name.plural
  end
end
