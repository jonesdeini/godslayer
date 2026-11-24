# frozen_string_literal: true

class CandidateClassificationWriter
  def self.write(candidate:, **attributes)
    new.write candidate:, **attributes
  end

  def write(candidate:, **attributes)
    CandidateClassification.transaction do
      candidate.candidate_classifications.where(active: true).update_all active: false
      candidate.candidate_classifications.create! attributes.merge(active: true)
    end
  end
end
