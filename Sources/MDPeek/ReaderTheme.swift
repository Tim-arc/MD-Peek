import MarkdownUI
import SwiftUI

extension Theme {
    @MainActor static let reader = Theme.gitHub
        .text {
            ForegroundColor(.primary)
            FontSize(17)
        }
        .link {
            ForegroundColor(Color(nsColor: .linkColor))
        }
        .code {
            FontFamilyVariant(.monospaced)
            FontSize(.em(0.87))
            BackgroundColor(Color.primary.opacity(0.07))
        }
        .heading1 { configuration in
            configuration.label
                .relativeLineSpacing(.em(0.12))
                .markdownMargin(top: 24, bottom: 22)
                .markdownTextStyle {
                    FontWeight(.bold)
                    FontSize(.em(2.1))
                }
        }
        .heading2 { configuration in
            configuration.label
                .relativeLineSpacing(.em(0.14))
                .markdownMargin(top: 34, bottom: 14)
                .markdownTextStyle {
                    FontWeight(.semibold)
                    FontSize(.em(1.48))
                }
        }
        .paragraph { configuration in
            configuration.label
                .fixedSize(horizontal: false, vertical: true)
                .relativeLineSpacing(.em(0.36))
                .markdownMargin(top: 0, bottom: 18)
        }
        .blockquote { configuration in
            configuration.label
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.primary.opacity(0.23))
                        .frame(width: 3)
                }
                .markdownMargin(top: 4, bottom: 20)
        }
        .table { configuration in
            configuration.label
                .fixedSize(horizontal: false, vertical: true)
                .markdownTableBorderStyle(.init(color: Color.primary.opacity(0.12)))
                .markdownTableBackgroundStyle(
                    .alternatingRows(.clear, Color.primary.opacity(0.035))
                )
                .clipShape(RoundedRectangle(cornerRadius: 7))
                .markdownMargin(top: 4, bottom: 22)
        }
        .tableCell { configuration in
            configuration.label
                .markdownTextStyle {
                    if configuration.row == 0 {
                        FontWeight(.semibold)
                    }
                    FontSize(.em(0.9))
                }
                .fixedSize(horizontal: false, vertical: true)
                .relativeLineSpacing(.em(0.21))
                .padding(.vertical, 10)
                .padding(.horizontal, 13)
        }
        .codeBlock { configuration in
            ScrollView(.horizontal) {
                configuration.label
                    .fixedSize(horizontal: true, vertical: true)
                    .relativeLineSpacing(.em(0.26))
                    .markdownTextStyle {
                        FontFamilyVariant(.monospaced)
                        FontSize(.em(0.86))
                    }
                    .padding(16)
            }
            .background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 9))
            .markdownMargin(top: 4, bottom: 22)
        }
}
