# typed: false
# frozen_string_literal: true

# This is a default, one-size-fits all protocol that shows how you can
# access the inputs and outputs of the operations associated with a job.
# Add specific instructions for this protocol!

needs 'Standard Libs/Debug'
needs 'Unsorted/ImportPartLibs'

class Protocol
  include Debug
  include ImportPartLibs

  CONCENTRATION = [0,0,3000,3000,3000, 7500, 7500, 7500].freeze
  STRIPWELL = '8 Well Stripwell'
  EXPERIMENT = "Experiment 3"

  def kit_contents
    {
      kit_1_8:{
        samples: ['DNA Aliquot', 'RNA Aliquot', 'Virus Aliquot'],
        primer_probes: ['RP', '2019-nCoVPC_N1', '2019-nCoVPC_N2'],
        rehydration_buffer: { sample: 'Rehydration Buffer', object_type: '5ml Bottle' }
      },
      kit_13_18: {
        samples: ['DNA Aliquot', 'RNA Aliquot'],
        primer_probes: ['RP', '2019-nCoVPC_N1', '2019-nCoVPC_N2'],
        rehydration_buffer: { sample: 'Rehydration Buffer', object_type: '5ml Bottle' }
      }
    }
  end

  def main
    kit_warning
    
    kit_numbers = []
    get_num_kits(EXPERIMENT).times { kit_numbers.push(get_kit_number) }
    
    contents_array = []
    kit_numbers.each do |kit_number|
        contents_array.push(
            { kit_number: kit_number,
              contents: get_contents(kit_number: kit_number, possible_kits: kit_contents)
            }
        )
    end
    
    created_parts = {primer_probe: [], sample: [], buffer: []}
    contents_array.each do |contents|
      kit_number = contents[:kit_number]
      created_parts[:primer_probe].append(create_primer_probe_stripwells(sample_names: contents[:contents][:primer_probes],
                                                                    kit_number: kit_number,
                                                                    repeat_number: contents[:contents][:samples].length,
                                                                    object_type_name: STRIPWELL,
                                                                    experiment_number: EXPERIMENT))

      created_parts[:sample].append(create_sample_stripwells(sample_names: contents[:contents][:samples],
                                                              kit_number: kit_number,
                                                              object_type_name: STRIPWELL,
                                                              experiment_number: EXPERIMENT,
                                                              concentrations: CONCENTRATION))

      created_parts[:buffer] = create_items(sample_info: contents[:contents][:rehydration_buffer],
                                            experiment_number: EXPERIMENT,
                                            kit_number: kit_number)
    end
    
    create_labels(parts_hash: created_parts)
    
    attatch_labels(created_parts: created_parts, experiment_number: EXPERIMENT)

    {}
  end
  
end