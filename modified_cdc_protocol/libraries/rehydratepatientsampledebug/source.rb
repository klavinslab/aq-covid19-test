# Library code here

needs 'Standard Libs/Debug'

module RehydratePatientSampleDebug
  include Debug

  SAMPLE_NAMES = ['Test Patient 01', 'Test Patient 02', 'nCoVPC'].freeze

  # Sets up test for debugging
  #
  # @param operations [OperationList] list of operations that need to be set up
  def setup_test(operations)
    option = operations.first.input_array('Template').first.collection.collection?
    operations.each do |op|
      op.set_input('Template', generate_strip_wells) if option
    end
  end

  # Generates fake populated strip wells
  #
  def generate_strip_wells
    samples = SAMPLE_NAMES.map { |sample_name| Sample.find_by_name(sample_name) }
    strip_wells = []
    3.times do 
      strip_well = Collection.new_collection('Strip Well')
      strip_well.add_samples(samples)
      strip_wells.push(strip_well)
    end
    strip_wells
  end
end
