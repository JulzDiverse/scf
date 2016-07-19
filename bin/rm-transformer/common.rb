# -*- coding: utf-8 -*-
## Common functionality for all providers.
# # ## ### ##### ########

# Common functionality for all providers.
class Common
  # # ## ### ##### ########
  ## Common status (options and derived DTR information)

  def initialize(options)
    @options = options
    initialize_dtr_information
  end

  def initialize_dtr_information
    # Get options, set defaults for missing parts
    @dtr         = @options[:dtr]
    @dtr_org     = @options[:dtr_org]
    @hcf_tag     = @options[:hcf_tag]
    @hcf_prefix  = @options[:hcf_prefix]
    @hcf_version = @options[:hcf_version]
  end

  # # ## ### ##### ########
  ## Predicates on roles.

  def typeof(role)
    role['type'] || 'bosh'
  end

  def flight_stage_of(role)
    role['run']['flight-stage'] || 'flight'
  end

  def tags_of(role)
    role['tags'] || []
  end

  def skip_manual?(role)
    flight_stage_of(role) == 'manual' && !@options[:manual]
  end

  def job?(role)
    flight_stage_of(role) == 'flight'
  end

  def task?(role)
    !job?(role)
  end

  # # ## ### ##### ########

  def self.product_version
    "4.0.0" # TODO: Make the minor here == cf-release's version?
  end
end
