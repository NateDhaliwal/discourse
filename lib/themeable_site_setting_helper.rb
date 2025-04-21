# frozen_string_literal: true

class ThemeableSiteSettingHelper
  attr_reader :theme_id

  def initialize(theme_id:)
    @theme_id = theme_id
  end

  # TODO (martin)
  #
  # What should the DB backing store here be? We are
  # storing site settings essentially...so maybe we
  # need a duplicate of the SiteSetting table?
  #
  # Need the following:
  #
  #   * name
  #   * data_type
  #   * value
  #   * theme_id
  #
  # Also need to take into account the theme about.json
  # overrides for the settings...
  #
  # Maybe need a new section in the about.json file like this:
  #
  # themeable_site_settings: {
  #   enable_welcome_banner: true
  # }
  #
  # The order needs to be something like:
  #
  # * Resolve db value for the theme
  # * If there is no db value, then use the about.json value for the theme
  # * If there is no db value or about.json value, then use the value from
  #   the site setting
  def resolved_themeable_site_settings
    themeable_site_setting_names = SiteSetting.themeable.select { |setting_name, value| value }.keys
    db_values = settings_from_store(themeable_site_setting_names)

    themeable_site_setting_names
      .each_with_object([]) do |setting, settings|
        type_hash = SiteSetting.type_supervisor.type_hash(setting)
        setting_hash = {
          setting: setting,
          type: type_hash[:type],
          # I think this makes more sense...if you are resetting it to the
          # default it means you want it the same as whatever the default
          # site setting is.
          default: SiteSetting.defaults[setting].to_s,
          description: SiteSetting.description(setting),
          valid_values: type_hash[:valid_values],
          translate_names: type_hash[:translate_names],
        }

        db_value = db_values.find { |db_setting| db_setting.name == setting.to_s }
        if !db_value.nil?
          setting_hash[:value] = SiteSetting
            .type_supervisor
            .to_rb_value(setting, db_value.value, db_value.data_type)
            .to_s
        else
          # TODO (martin)
          #
          # Dont think we can do this at runtime, we have to do this at
          # import time for themes the same way we do for screenshots :/
          #
          # Maybe we always need a ThemeSiteSetting entry, if the theme
          # is changing the default from the site setting?
          #
          # Hmm...this may make it harder to change defaults for site settings though
          # about_json_value = @theme.about_json["themeable_site_settings"]&.dig(setting)
          #
          # What if we store a dump of the defaults as JSON in a ThemeField?
          about_json_value = nil
          if !about_json_value.nil?
            # hash[setting] = about_json_value
          else
            # We use `current` here because we want the raw site setting value without
            # validations.
            setting_hash[:value] = SiteSetting.current[setting].to_s
          end
        end

        settings << setting_hash
      end
      .sort_by { |s| s[:setting] }
  end

  def settings_from_store(themeable_site_setting_names)
    database_values =
      ThemeSiteSetting.where(theme_id: @theme_id, name: themeable_site_setting_names)
  end
end
