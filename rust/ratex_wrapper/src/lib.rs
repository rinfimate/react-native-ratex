uniffi::setup_scaffolding!();

#[derive(Debug, thiserror::Error, uniffi::Error)]
pub enum RatexError {
    #[error("{message}")]
    RenderError { message: String },
}

#[uniffi::export]
pub fn render_to_svg(latex: String, display_mode: bool, font_size: f64) -> Result<String, RatexError> {
    latex_wrapper::render_to_svg(latex, display_mode, font_size)
        .map_err(|e| RatexError::RenderError { message: e.to_string() })
}

#[uniffi::export]
pub fn render_to_view(latex: String, display_mode: bool) -> Result<String, RatexError> {
    latex_wrapper::render_to_view(latex, display_mode)
        .map_err(|e| RatexError::RenderError { message: e.to_string() })
}
