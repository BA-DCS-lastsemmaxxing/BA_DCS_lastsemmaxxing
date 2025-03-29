import React, { useEffect, useState } from "react";
import { getAllTopics } from "@/service/modelApi";

interface ClassificationFilterProps {
  classificationFilter: string;
  setClassificationFilter: (value: string) => void;
}

interface TopicCategory {
  name: string;
  emoji?: string;
  children?: TopicCategory[];
}

const ClassificationFilter: React.FC<ClassificationFilterProps> = ({
  classificationFilter,
  setClassificationFilter,
}) => {
  const [topicCategories, setTopicCategories] = useState<TopicCategory[]>([]);
  const [isLoading, setIsLoading] = useState(true);

  useEffect(() => {
    const fetchTopics = async () => {
      try {
        setIsLoading(true);
        const response = await getAllTopics();
        
        // Transform the flat list of topics into a hierarchical structure
        const categories = processTopics(response.topics.map((t :{ topic_name: string }) => t.topic_name));
        setTopicCategories(categories);
      } catch (error) {
        console.error("Error fetching topics for classification filter:", error);
      } finally {
        setIsLoading(false);
      }
    };

    fetchTopics();
  }, []);

  // Process topics into a hierarchical structure
  const processTopics = (topics: string[]): TopicCategory[] => {
    // Define top-level categories with emojis
    const predefinedCategories: Record<string, string> = {
      "Operational": "🔹",
      "Administrative": "📋",
      "Strategic": "📊",
      "Technology": "🖥️",
      "Market and Public Communications": "📣",
      "Regulatory and Compliance": "📜",
      "Risk Management": "⚠️",
      "Legal and Contractual": "📜",
      "Financial": "💹",
      "Others": "📄" // Add Others category
    };

    // Create a map to store the hierarchy
    const categoryMap: Record<string, TopicCategory> = {};
    
    // Initialize the Others category
    categoryMap["Others"] = {
      name: "Others",
      emoji: predefinedCategories["Others"],
      children: []
    };
    
    // First pass: create all categories
    topics.forEach(topic => {
      // Check if this is a top-level category
      if (predefinedCategories[topic]) {
        if (!categoryMap[topic]) {
          categoryMap[topic] = {
            name: topic,
            emoji: predefinedCategories[topic],
            children: []
          };
        }
      } else {
        // Try to find a parent category
        let foundParent = false;
        for (const category in predefinedCategories) {
          if (category === "Others") continue; // Skip Others in this loop
          
          if (topic.includes(category) || 
              // Handle special cases like "Anti Money Laundering" belonging to "Regulatory and Compliance"
              (category === "Regulatory and Compliance" && 
               ["Consumer Finance", "Anti Money Laundering", "Financial Regulations", "Taxation"].includes(topic)) ||
              (category === "Risk Management" && 
               ["Audit Reports"].includes(topic)) ||
              (category === "Legal and Contractual" && 
               ["Employment", "Loans", "Client Agreements", "Non-Disclosure Agreements", 
                "Derivatives", "Partnerships", "Mergers & Acquisitions"].includes(topic)) ||
              (category === "Financial" && 
               ["Investments & Market Research", "Annual Reports"].includes(topic))
          ) {
            // Create parent category if it doesn't exist
            if (!categoryMap[category]) {
              categoryMap[category] = {
                name: category,
                emoji: predefinedCategories[category],
                children: []
              };
            }
            
            // Add this topic as a child
            if (!categoryMap[topic]) {
              // Assign emoji based on known subcategories
              let emoji = "";
              switch (topic) {
                case "Consumer Finance": emoji = "💰"; break;
                case "Anti Money Laundering": emoji = "🚨"; break;
                case "Financial Regulations": emoji = "⚖️"; break;
                case "Taxation": emoji = "💵"; break;
                case "Audit Reports": emoji = "📑"; break;
                case "Employment": emoji = "👔"; break;
                case "Loans": emoji = "🏦"; break;
                case "Client Agreements": emoji = "📝"; break;
                case "Non-Disclosure Agreements": emoji = "🤐"; break;
                case "Derivatives": emoji = "📉"; break;
                case "Partnerships": emoji = "🤝"; break;
                case "Mergers & Acquisitions": emoji = "🔄"; break;
                case "Investments & Market Research": emoji = "📈"; break;
                case "Annual Reports": emoji = "📆"; break;
                default: emoji = "📄"; break;
              }
              
              categoryMap[topic] = {
                name: topic,
                emoji: emoji
              };
            }
            
            if (categoryMap[category].children) {
              // Only add if not already in the children array
              if (!categoryMap[category].children?.some(child => child.name === topic)) {
                categoryMap[category].children?.push(categoryMap[topic]);
              }
            }
            
            foundParent = true;
            break;
          }
        }
        
        // If no parent found, add to Others category
        if (!foundParent && !categoryMap[topic]) {
          categoryMap[topic] = {
            name: topic,
            emoji: "📄" // Default emoji for uncategorized topics
          };
          
          // Add to Others category
          if (!categoryMap["Others"].children?.some(child => child.name === topic)) {
            categoryMap["Others"].children?.push(categoryMap[topic]);
          }
        }
      }
    });
    
    // Convert the map to an array of top-level categories
    const result: TopicCategory[] = [];
    for (const category in predefinedCategories) {
      if (categoryMap[category] && (category !== "Others" || (categoryMap["Others"].children && categoryMap["Others"].children.length > 0))) {
        result.push(categoryMap[category]);
      }
    }
    
    return result;
  };

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
        disabled={isLoading}
      >
        <option value="">All</option>
        
        {isLoading ? (
          <option value="" disabled>Loading categories...</option>
        ) : (
          topicCategories.map(category => (
            <React.Fragment key={category.name}>
              <optgroup label={category.name}>
                <option value={category.name}>
                  &nbsp;&nbsp;{category.emoji} {category.name}
                </option>
                
                {category.children?.map(child => (
                  <option key={child.name} value={child.name}>
                    &nbsp;&nbsp;&nbsp;&nbsp;{child.emoji} {child.name}
                  </option>
                ))}
              </optgroup>
            </React.Fragment>
          ))
        )}
      </select>
    </div>
  );
};

export default ClassificationFilter;
