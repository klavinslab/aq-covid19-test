# typed: false
# frozen_string_literal: true

needs 'Standard Libs/PlanParams'
needs 'Standard Libs/CommonInputOutputNames'
needs 'Standard Libs/Debug'
needs 'Standard Libs/Pipettors'
needs 'Standard Libs/LabwareNames'
needs 'Collection Management/CollectionActions'
needs 'Collection Management/CollectionDisplay'
needs 'Collection Management/CollectionTransfer'
needs 'Diagnostic RT-qPCR/DiagnosticRTqPCRDebug'
needs 'Diagnostic RT-qPCR/DiagnosticRTqPCRCompositions'
needs 'Diagnostic RT-qPCR/ProtocolSurvey'
needs 'Tube Rack/TubeRackHelper'

# Module for elements that are common throughout Diagnostic RT qPCR
#
# @author Devin Strickland <strcklnd@uw.edu>
module DiagnosticRTqPCRHelper
  # Standard Libs
  include Units
  include PlanParams
  include CommonInputOutputNames
  include Debug
  include Pipettors
  include LabwareNames

  # Collection Management
  include CollectionActions
  include CollectionDisplay
  include CollectionTransfer

  # Diagnostic RT-qPCR
  include DataAssociationKeys
  include DiagnosticRTqPCRDebug
  include DiagnosticRTqPCRCompositions
  include ProtocolSurvey
  
  # TubeRack
  include TubeRackHelper

  WATER = 'Molecular Grade Water'
  WATER_OBJECT_TYPE = 'Reagent Aliquot'
  PLATE = 'PCR Plate'
  PLATE_OBJECT_TYPE = '96-well qPCR Plate'
  PRIMER_MIX = 'Primer/Probe Mix'
  MASTER_MIX_OBJECT_TYPE = 'qPCR Master Mix Stock'
  SPECIMEN = 'Specimen'

  RNA_FREE_WORKSPACE = 'reagent set-up room'

  def rnase_warning
    show do
      title 'RNase degrades RNA'
      note 'RNA is prone to degradation by RNase present in our eyes, skin, and breath.'
      note 'Avoid opening tubes outside the Biosafety Cabinet (BSC).'
      bullet 'Change gloves whenever you suspect potential RNAse contamination'
    end
  end

  def safety_warning
    show do
      title 'Review Safety Warnings'
      note '<b>Always</b> pay attention to orange warning blocks throughout the protocol.'
      warning '<b>INFECTIOUS MATERIALS</b>'
      note 'You will be working with infectious materials.'
      note 'Do <b>ALL</b> work in a biosafety cabinet (BSC).'
      note '<b>PPE is required</b>'
      check 'Put on lab coat.'
      check 'Put on 2 layers of gloves.'
      bullet 'Make sure to use tight gloves. Tight gloves reduce the chance of the gloves getting caught on the tubes when closing their lids.'
      bullet 'Change outer layer of gloves after handling infectious sample and before touching surfaces outside of the BSC (such as a refrigerator door handle).'
    end
  end

  # Adds samples to to collections, provides instructions to tech
  #
  # @param compositions [Array<PCRCompostion>]
  # @param microtiter_plate [MicrotiterPlate]
  # @param column [int]
  def add_samples(compositions:, microtiter_plate:, column: nil)

    grouped_comps = compositions.group_by{ |comp| comp.template.item.is_part }
    if grouped_comps[false]
      add_single_samples(compositions: grouped_comps[false],
                         microtiter_plate: microtiter_plate,
                         column: column)
    elsif grouped_comps[true]
      add_coll_samples(compositions: grouped_comps[true],
                       microtiter_plate: microtiter_plate,
                       column: column)
    else
      raise 'the compositions are neither a part nor not a part' 
    end
  end
  
  def add_coll_samples(compositions:, microtiter_plate:, column: nil)
    grouped_comps = compositions.group_by{ |comp| comp.template.item.containing_collection }
    grouped_comps.each do |collection, comps|
      collection = Collection.find(collection.id)
      association_map = []
      comps.each do |comp|
        layout_group = microtiter_plate.next_empty_group(
          key: TEMPLATE_KEY,
          column: column
        )

        from_loc = find_item_in_collection(collection: collection, item: comp.template.item)
        layout_group.each do |to_loc|
          association_map.push({ from_loc: from_loc, to_loc: to_loc }) 
        end
        
        microtiter_plate.associate_provenance_group(
          group: layout_group,
          key: TEMPLATE_KEY,
          data: added_component_data(composition: comp)
        )
      end
      
      association_map.group_by { |map| map[:to_loc][0] }.each do |_row, ass_map|
        multichannel_collection_to_collection(
          to_collection: microtiter_plate.collection,
          from_collection: collection,
          volume: comps.first.template.volume_hash,
          association_map: ass_map
        )
      end
      
      comps.each { |comp| comp.template.added = true }
      
    end
  end
  
  def add_single_samples(compositions:, microtiter_plate:, column: nil)
    compositions.each do |composition|
      layout_group = microtiter_plate.next_empty_group(
        key: TEMPLATE_KEY,
        column: column
      )

      single_channel_item_to_collection(
        to_collection: microtiter_plate.collection,
        source: composition.template.item,
        volume: composition.template.volume_hash,
        association_map: layout_group.map { |r, c| { to_loc: [r, c] } }
      )

      composition.template.added = true

      microtiter_plate.associate_provenance_group(
        group: layout_group,
        key: TEMPLATE_KEY,
        data: added_component_data(composition: composition)
      )
    end
  end

  # Instruct technician to do everything necessary to prepare the workspace
  #
  # @return [void]
  def show_prepare_workspace
    show do
      title 'Prepare workspace'

      note "All tasks in this protocol occur in the #{RNA_FREE_WORKSPACE}."
      note 'As you retrieve reagents, place them on ice or in a cold-block.'
    end
  end

  ########## ITEM METHODS ##########

  # Finds a master mix Item in inventory
  #
  # @param sample [Sample] of qPCR Master Mix
  # @return [Item]
  def master_mix_item(sample:)
    get_item(
      sample: sample,
      object_type_name: MASTER_MIX_OBJECT_TYPE
    )
  end

  # Finds a water Item in inventory
  #
  # @return [Item]
  def water_item
    get_item(
      sample: Sample.find_by_name(WATER),
      object_type_name: WATER_OBJECT_TYPE
    )
  end

  # Finds a water Item in inventory for no template control
  #
  # @return [Item]
  def no_template_control_item
    water_item
  end

  # Finds an Item in inventory for the given `Sample` and `ObjectType`
  # @todo replace with a back-end method such as `Sample.in`
  #
  # @param sample [Sample]
  # @param object_type_name [String]
  # @return [Item]
  def get_item(sample:, object_type_name:)
    Item.with_sample(sample: sample)
        .where(object_type: ObjectType.find_by_name(object_type_name))
        .reject(&:deleted?)
        .first
  end

  # Return Item IDs as a string with one or more ID ranges represented as
  #   the beginning and end separated by a hyphen. Currently raises an
  #   exception if the numbers are non-consecutive.
  #
  # @param items [Array<Item>]
  # @return [String]
  def id_ranges_display(items:)
    ids = items.map(&:id).sort
    ranges = []
    range = [ids.shift]

    ids.each do |id|
      if id == range.last + 1
        range.append(id)
      else
        ranges.append(range)
        range = [id]
      end
    end
    ranges.append(range)

    ranges.map! { |r| r.length == 1 ? r.first.to_s : "#{r.first} - #{r.last}" }
    ranges.to_sentence
  end

  ########## PROVENANCE METHODS ##########

  # Add provenance metadata to a stock item and aliquots made from that stock
  #
  # @param stock_item [Item] the source item for the aliquot operation
  # @param aliquot_items [Array<Item>] the aliqouts made in the operation
  # @return [void]
  def add_aliquot_provenance(stock_item:, aliquot_items:)
    from_map = AssociationMap.new(stock_item)
    to_maps = aliquot_items.map { |a| [a, AssociationMap.new(a)] }

    to_maps.each do |aliquot_item, to_map|
      add_provenance(
        from: stock_item, from_map: from_map,
        to: aliquot_item, to_map: to_map
      )
      from_map.save
      to_map.save
    end
  end

  def add_one_to_one_provenance(from_item:, to_item:)
    from_map = AssociationMap.new(from_item)
    to_map = AssociationMap.new(to_item)

    add_provenance(
      from: from_item, from_map: from_map,
      to: to_item, to_map: to_map
    )
    from_map.save
    to_map.save
  end

  ################### Provision Plate Methods ################

  # Creates and assigns an output collection for each operation, and fills it
  #   with the output sample according to the provided PlateLayoutGenerator
  #   method
  # @note In debug mode, displays the matrix of each collection
  #
  # @param operations [OperationList]
  # @param object_type [String] the ObjectType of the collection to be made
  # @return [void]
  def provision_plates(operations:)
    operations.each do |op|
      collection = op.output(PLATE).make_collection
      get_and_label_new_plate(collection)

      set_parts(
        collection: collection,
        group_size: op.temporary[:options][:group_size],
        method: op.temporary[:options][:layout_method],
        sample: op.output(PLATE).sample
      )

      inspect op.output(PLATE).collection.matrix if debug
    end
  end

  # Fills a collection with the provided sample according to the provided
  #   PlateLayoutGenerator method
  #
  # @param collection [Collection]
  # @param group_size [Fixnum]
  # @param method [String] a PlateLayoutGenerator method
  # @param sample [Sample] the Sample to add to the collection
  # @return [void]
  def set_parts(collection:, group_size:, method:, sample:, num_loops: nil)
    layout_generator = PlateLayoutGeneratorFactory.build(
      group_size: group_size,
      method: method,
      dimensions: collection.dimensions
    )

    idx = 0

    loop do
      index = layout_generator.next
      break unless index.present?
      
      break if idx == num_loops

      collection.set(index[0], index[1], sample)
      idx += 1
    end
  end

  ############# STRIPWELL METHODS ############

  # Adds a stripwell to a microtiter plate
  #
  # @param composition_group [Array<Compositions>] list of compositions that are
  #    all contained in the same stripwell
  # @param microtiter_plate [MicrotiterPlate]
  def add_stripwell(composition_group:, microtiter_plate:, stripwell:, key:)
    layout_group = microtiter_plate.next_empty_group(key: key)
    composition_group.zip(layout_group).each do |composition, lyt|
      raise 'layout group is nil' if lyt.nil?
      data = added_component_data(composition: composition)
      microtiter_plate.associate_provenance(index: lyt,
                                            key: key,
                                            data: data)
    end
    show_mark_stripwell(stripwell: stripwell)
    show_add_stripwell(location: layout_group,
                       stripwell: stripwell,
                       tube_rack: microtiter_plate.collection)
  end

  # Directions to mark a stripwell correctly
  #
  # @param stripwell [Colleciton]
  def show_mark_stripwell(stripwell:)
    show do
      title 'Mark Stripwell'
      note 'Using a felt tip marker please mark'\
        " stripwell #{stripwell.id}"
      note "Mark one end <b>1</b> and the other <b>#{stripwell.dimensions[1]}"
      warning 'Do NOT mark the lids of the stripwell!'
    end
  end
end
