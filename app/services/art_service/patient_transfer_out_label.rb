# frozen_string_literal: true

module ArtService
  # Prints out patient transfer out labels
  #
  # Source: NART/app/controllers/generic_patients_controller#patient_transfer_out_label
  class PatientTransferOutLabel
    attr_reader :patient, :date, :transfer_out_note

    def initialize(patient, date)
      @patient = patient
      @date = date
      @transfer_out_note = ArtService::PatientTransferOut.new patient, date
    end

    def print
      # Gather the information
      who_stage = transfer_out_note.reason_for_art_eligibility
      initial_staging_conditions = transfer_out_note.who_clinical_conditions
      destination = transfer_out_note.transferred_out_to
      art_start_date = transfer_out_note.date_antiretrovirals_started&.strftime("%d/%b/%Y")

      # Process the initial staging conditions
      staging_conditions = ""
      count = 1
      initial_staging_conditions.each do |condition|
        if staging_conditions.blank?
          staging_conditions = "(#{count}) #{condition}" unless condition.blank?
        else
          staging_conditions += " (#{count += 1}) #{condition}" unless condition.blank?
        end
      end

      initial_height = "Init HT: #{transfer_out_note.initial_height}"
      initial_weight = "Init WT: #{transfer_out_note.initial_weight}"
      first_cd4_count = "CD count #{transfer_out_note.cd4_count}" if transfer_out_note.cd4_count
      first_cd4_count_date = "CD count date #{transfer_out_note.cd4_count_date.strftime("%d/%b/%Y")}" unless transfer_out_note.cd4_count_date.blank?

      # Process the current ART drugs
      concept_id = Concept.find_by_name("AMOUNT DISPENSED").id
      previous_orders = Order.joins("INNER JOIN obs ON obs.order_id = orders.order_id LEFT JOIN drug_order ON
          orders.order_id = drug_order.order_id").where(["obs.person_id = ? AND obs.concept_id = ?
              AND obs_datetime <=?", patient.id, concept_id, date.strftime("%Y-%m-%d 23:59:59")]).order("obs_datetime DESC").select("obs.obs_datetime, drug_order.drug_inventory_id")

      previous_date = nil
      drugs = []
      finished = false
      reg = []

      previous_orders.each do |order|
        drug = Drug.find(order.drug_inventory_id)
        next unless drug.arv?
        next if finished

        previous_date = order.obs_datetime.to_date if previous_date.blank?
        if previous_date == order.obs_datetime.to_date
          reg << (drug.concept.shortname || drug.concept.fullname)
          previous_date = order.obs_datetime.to_date
        else
          finished = true unless drugs.blank?
        end
      end

      reg = reg.uniq.join(" + ")
      transfer_out_date = actual_transfer_out_date.strftime("%d/%b/%Y")

      # Proceed with the label creation
      label = ZebraPrinter::Lib::Label.new(776, 329, "T")
      label.line_spacing = 0
      label.top_margin = 30
      label.bottom_margin = 30
      label.left_margin = 25
      label.x = 25
      label.y = 30
      label.font_size = 3
      label.font_horizontal_multiplier = 1
      label.font_vertical_multiplier = 1

      # Patient personal data
      label.draw_multi_text("#{Location.current_health_center.name} transfer out label", font_reverse: true)
      label.draw_multi_text("To #{destination}", font_reverse: false) unless destination.blank?
      label.draw_multi_text("ARV number: #{patient.identifier("ARV Number")&.identifier}", font_reverse: true)
      label.draw_multi_text("Name: #{patient.name}\nAge: #{patient.age}", font_reverse: false)

      # Diagnosis information
      label.draw_multi_text("Stage defining conditions:", font_reverse: true)
      label.draw_multi_text("Reason for starting: #{who_stage}", font_reverse: false)
      label.draw_multi_text("ART start date: #{art_start_date}", font_reverse: false)
      label.draw_multi_text("Other diagnosis:", font_reverse: true)
      label.draw_multi_text(staging_conditions.to_s, font_reverse: false)

      # Initial Height/Weight and CD4 count
      label.draw_multi_text("Initial Height/Weight", font_reverse: true)
      label.draw_multi_text("#{initial_height} #{initial_weight}", font_reverse: false)
      label.draw_multi_text(first_cd4_count.to_s, font_reverse: false)
      label.draw_multi_text(first_cd4_count_date.to_s, font_reverse: false)

      # Current ART drugs and transfer out date
      label.draw_multi_text("Current ART drugs", font_reverse: true)
      label.draw_multi_text(reg, font_reverse: false)
      label.draw_multi_text("Transfer out date:", font_reverse: true)
      label.draw_multi_text(transfer_out_date, font_reverse: false)

      {
        zpl: label.print(1),
        data: {
          health_center: Location.current_health_center.name,
          destination: destination,
          arv_number: patient.identifier("ARV Number")&.identifier,
          name: "#{patient.name} (#{patient.gender.first})",
          age: patient.age,
          reason_for_starting: who_stage,
          art_start_date: art_start_date,
          staging_conditions: staging_conditions,
          initial_height: transfer_out_note.initial_height,
          initial_weight: transfer_out_note.initial_weight,
          first_cd4_count: transfer_out_note.cd4_count,
          first_cd4_count_date: transfer_out_note.cd4_count_date&.strftime("%d/%b/%Y"),
          current_art_drugs: reg,
          transfer_out_date: transfer_out_date,
        },
      }
    end

    # method to get transfer out date
    def actual_transfer_out_date
      record = PatientState
        .joins(
          "LEFT JOIN (patient_program) on (patient_state.patient_program_id = patient_program.patient_program_id)"
        )
        .where(patient_program: { patient_id: patient.patient_id,
                                  program_id: Program.find_by_name!("HIV Program").program_id })
        .where("patient_state.state=2 AND patient_state.start_date <= DATE('#{date.to_date}')")
        .order(start_date: :desc)
      record.blank? ? date : record.first.start_date.to_date
    end
  end
end
