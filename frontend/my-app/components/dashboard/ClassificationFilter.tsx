import React from "react";

interface ClassificationFilterProps {
  classificationFilter: string;
  setClassificationFilter: (value: string) => void;
}

const ClassificationFilter: React.FC<ClassificationFilterProps> = ({
  classificationFilter,
  setClassificationFilter,
}) => {
  const handleClassificationFilter = (event: React.ChangeEvent<HTMLSelectElement>) => {
    setClassificationFilter(event.target.value);
  };

  return (
    <div className="flex-1">
      <label className="block text-gray-700 text-sm font-bold mb-1">
        Filter by Classification:
      </label>
      <select
        className="border rounded w-full p-2 bg-white shadow-sm focus:ring focus:ring-blue-200"
        value={classificationFilter}
        onChange={handleClassificationFilter}
      >
        <option value="">All</option>
        <optgroup label="Operational">
          <option value="Operational">&nbsp;&nbsp;🔹 Operational</option>
        </optgroup>
        <optgroup label="Administrative">
          <option value="Administrative">&nbsp;&nbsp;📋 Administrative</option>
        </optgroup>
        <optgroup label="Strategic">
          <option value="Strategic">&nbsp;&nbsp;📊 Strategic</option>
        </optgroup>
        <optgroup label="Technology">
          <option value="Technology">&nbsp;&nbsp;🖥️ Technology</option>
        </optgroup>
        <optgroup label="Market and Public Communications">
          <option value="Market and Public Communications">&nbsp;&nbsp;📣 Market and Public Communications</option>
        </optgroup>
        <optgroup label="Regulatory and Compliance">
          <option value="Regulatory and Compliance">&nbsp;&nbsp;📜 Regulatory and Compliance</option>
          <option value="Consumer Finance">&nbsp;&nbsp;&nbsp;&nbsp;💰 Consumer Finance</option>
          <option value="Anti Money Laundering">&nbsp;&nbsp;&nbsp;&nbsp;🚨 Anti Money Laundering</option>
          <option value="Financial Regulations">&nbsp;&nbsp;&nbsp;&nbsp;⚖️ Financial Regulations</option>
          <option value="Taxation">&nbsp;&nbsp;&nbsp;&nbsp;💵 Taxation</option>
        </optgroup>
        <optgroup label="Risk Management">
          <option value="Risk Management">&nbsp;&nbsp;⚠️ Risk Management</option>
          <option value="Audit Reports">&nbsp;&nbsp;&nbsp;&nbsp;📑 Audit Reports</option>
        </optgroup>
        <optgroup label="Legal and Contractual">
          <option value="Legal and Contractual">&nbsp;&nbsp;📜 Legal and Contractual</option>
          <option value="Employment">&nbsp;&nbsp;&nbsp;&nbsp;👔 Employment</option>
          <option value="Loans">&nbsp;&nbsp;&nbsp;&nbsp;🏦 Loans</option>
          <option value="Client Agreements">&nbsp;&nbsp;&nbsp;&nbsp;📝 Client Agreements</option>
          <option value="Non-Disclosure Agreements">&nbsp;&nbsp;&nbsp;&nbsp;🤐 Non-Disclosure Agreements</option>
          <option value="Derivatives">&nbsp;&nbsp;&nbsp;&nbsp;📉 Derivatives</option>
          <option value="Partnerships">&nbsp;&nbsp;&nbsp;&nbsp;🤝 Partnerships</option>
          <option value="Merges and Acquisitions">&nbsp;&nbsp;&nbsp;&nbsp;🔄 Mergers & Acquisitions</option>
        </optgroup>
        <optgroup label="Financial">
          <option value="Financial">&nbsp;&nbsp;💹 Financial</option>
          <option value="Investments and Market Research">&nbsp;&nbsp;&nbsp;&nbsp;📈 Investments & Market Research</option>
          <option value="Annual Reports">&nbsp;&nbsp;&nbsp;&nbsp;📆 Annual Reports</option>
        </optgroup>
      </select>
    </div>
  );
};

export default ClassificationFilter;
