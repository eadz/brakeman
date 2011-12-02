require 'brakeman/checks/base_check'

#Checks for mass assignments to models.
#
#See http://guides.rubyonrails.org/security.html#mass-assignment for details
class Brakeman::CheckMassAssignment < Brakeman::BaseCheck
  Brakeman::Checks.add self

  def run_check
    return if mass_assign_disabled?

    models = []
    tracker.models.each do |name, m|
      if parent?(tracker, m, :"ActiveRecord::Base") and m[:attr_accessible].nil?
        models << name
      end
    end

    return if models.empty?

    @results = Set.new

    debug_info "Finding possible mass assignment calls on #{models.length} models"
    calls = tracker.find_call models, [:new,
      :attributes=, 
      :update_attribute, 
      :update_attributes, 
      :update_attributes!,
      :create,
      :create!]

    debug_info "Processing possible mass assignment calls"
    calls.each do |result|
      process result
    end
  end

  #All results should be Model.new(...) or Model.attributes=() calls
  def process_result res
    call = res[-1]

    check = check_call call

    if check and not @results.include? call
      @results << call

      if include_user_input? call[3] and not hash? call[3][1]
        confidence = CONFIDENCE[:high]
      else
        confidence = CONFIDENCE[:low]
      end
      
      warn :result => res, 
        :warning_type => "Mass Assignment", 
        :message => "Unprotected mass assignment",
        :line => call.line,
        :code => call, 
        :confidence => confidence
    end

    res
  end

  #Want to ignore calls to Model.new that have no arguments
  def check_call call
    args = process call[3]
    if args.length <= 1 #empty new()
      false
    elsif hash? args[1] and not include_user_input? args[1]
      false
    else
      true
    end
  end

end
