use std::{fmt, ops::Deref, str::FromStr};

use serde::Deserialize;

#[derive(Clone, Debug, PartialEq, Eq, Deserialize)]
#[serde(try_from = "String")]
pub struct ModelName(String);

impl ModelName {
    pub fn as_str(&self) -> &str {
        &self.0
    }
}

impl TryFrom<String> for ModelName {
    type Error = String;

    fn try_from(name: String) -> Result<Self, Self::Error> {
        let trimmed = name.trim();
        if trimmed.is_empty() || trimmed.contains(',') {
            return Err(format!(
                "Invalid model name '{name}': must be non-empty and must not contain ','"
            ));
        }
        Ok(ModelName(trimmed.to_string()))
    }
}

impl FromStr for ModelName {
    type Err = String;

    fn from_str(name: &str) -> Result<Self, Self::Err> {
        name.to_string().try_into()
    }
}

impl fmt::Display for ModelName {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        f.write_str(&self.0)
    }
}

#[derive(Clone, Debug, Deserialize)]
#[serde(try_from = "Vec<ModelName>")]
pub struct ModelsList(Vec<ModelName>);

impl TryFrom<Vec<ModelName>> for ModelsList {
    type Error = &'static str;

    fn try_from(models: Vec<ModelName>) -> Result<Self, Self::Error> {
        if models.is_empty() {
            return Err("models list must not be empty");
        }
        Ok(ModelsList(models))
    }
}

impl Deref for ModelsList {
    type Target = [ModelName];

    fn deref(&self) -> &Self::Target {
        &self.0
    }
}

pub fn join(models: &[ModelName]) -> String {
    models
        .iter()
        .map(ModelName::as_str)
        .collect::<Vec<_>>()
        .join(",")
}
