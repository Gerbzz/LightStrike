//! Independent LightStrike introduction and About artwork.
//!
//! The PWDS bitmap is the existing approved company mark, with separate terms
//! in assets/branding/LICENSE-brand.txt. It is not derived from ArtCraft marks.

use egui::{Align2, Color32, FontId, Rect, TextureHandle, TextureOptions, Vec2, pos2, vec2};

static PWDS_MARK: &[u8] = include_bytes!("../../../assets/branding/PWDS-logo.png");

fn mark(ctx: &egui::Context) -> Option<TextureHandle> {
    let id = egui::Id::new("lightstrike-pwds-mark");
    if let Some(texture) = ctx.data(|data| data.get_temp::<TextureHandle>(id)) {
        return Some(texture);
    }
    let bitmap = image::load_from_memory_with_format(PWDS_MARK, image::ImageFormat::Png).ok()?.to_rgba8();
    let pixels = egui::ColorImage::from_rgba_unmultiplied([bitmap.width() as usize, bitmap.height() as usize], bitmap.as_raw());
    let texture = ctx.load_texture("lightstrike-pwds-mark", pixels, TextureOptions::LINEAR);
    ctx.data_mut(|data| data.insert_temp(id, texture.clone()));
    Some(texture)
}

fn paint_mark(ui: &egui::Ui, plaque: Rect) {
    let painter = ui.painter();
    painter.rect_filled(plaque, 10.0, Color32::WHITE);
    if let Some(texture) = mark(ui.ctx()) {
        let image = Rect::from_center_size(plaque.center(), vec2(plaque.width() - 16.0, (plaque.width() - 16.0) * 129.0 / 300.0));
        painter.image(texture.id(), image, Rect::from_min_max(pos2(0.0, 0.0), pos2(1.0, 1.0)), Color32::WHITE);
    }
}

/// A short native launch screen while the first workspace frame is prepared.
pub fn startup(ui: &mut egui::Ui) {
    egui::CentralPanel::default().frame(egui::Frame::NONE.fill(Color32::from_rgb(13, 18, 32))).show(ui, |ui| {
        let area = ui.max_rect();
        let width = (area.width() - 40.0).min(620.0).max(300.0);
        let card = Rect::from_center_size(area.center(), vec2(width, 280.0));
        let painter = ui.painter();
        painter.rect_filled(card, 22.0, Color32::from_rgb(26, 34, 54));
        painter.rect_filled(Rect::from_min_size(card.min, vec2(card.width(), 5.0)), 2.0, Color32::from_rgb(236, 162, 73));
        let plaque = Rect::from_center_size(pos2(card.center().x, card.top() + 80.0), vec2(206.0, 96.0));
        paint_mark(ui, plaque);
        painter.text(pos2(card.center().x, card.top() + 163.0), Align2::CENTER_CENTER, "LightStrike", FontId::proportional(32.0), Color32::WHITE);
        painter.text(
            pos2(card.center().x, card.top() + 207.0),
            Align2::CENTER_CENTER,
            "PHOTO LIBRARY  /  RAW DEVELOPMENT",
            FontId::proportional(13.0),
            Color32::from_rgb(188, 199, 218),
        );
        painter.text(
            pos2(card.center().x, card.top() + 246.0),
            Align2::CENTER_CENTER,
            "Preparing your workspace",
            FontId::proportional(13.0),
            Color32::from_rgb(142, 156, 178),
        );
    });
}

/// About header: approved mark, product name, and inherited version.
pub fn about(ui: &mut egui::Ui, version: &str) {
    let size = Vec2::new(ui.available_width(), 116.0);
    let (card, _) = ui.allocate_exact_size(size, egui::Sense::hover());
    let painter = ui.painter();
    painter.rect_filled(card, 12.0, Color32::from_rgb(26, 34, 54));
    let plaque = Rect::from_min_size(card.min + vec2(16.0, 20.0), vec2(164.0, 76.0));
    paint_mark(ui, plaque);
    painter.text(card.min + vec2(198.0, 47.0), Align2::LEFT_CENTER, "LightStrike", FontId::proportional(26.0), Color32::WHITE);
    painter.text(
        card.min + vec2(198.0, 76.0),
        Align2::LEFT_CENTER,
        format!("Version {version}  ·  Photo library and raw development"),
        FontId::proportional(13.0),
        Color32::from_rgb(188, 199, 218),
    );
}
