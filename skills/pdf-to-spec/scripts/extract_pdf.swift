#!/usr/bin/swift
import Foundation
import PDFKit
import Vision
import AppKit

// PDFKit으로 텍스트 레이어 추출 (일반 PDF)
func extractWithPDFKit(url: URL) -> String? {
    guard let pdf = PDFDocument(url: url) else { return nil }
    var result = ""
    for i in 0..<pdf.pageCount {
        guard let page = pdf.page(at: i),
              let text = page.string,
              !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { continue }
        result += "=== Page \(i + 1) ===\n\(text)\n\n"
    }
    return result.isEmpty ? nil : result
}

// Vision OCR로 텍스트 추출 (스캔 PDF / 이미지 PDF)
func extractWithVisionOCR(url: URL) -> String {
    guard let pdf = PDFDocument(url: url) else { return "" }
    var result = ""

    for pageIndex in 0..<pdf.pageCount {
        guard let page = pdf.page(at: pageIndex) else { continue }

        let bounds = page.bounds(for: .mediaBox)
        let scale: CGFloat = 2.0
        let thumbSize = CGSize(width: bounds.width * scale, height: bounds.height * scale)
        let thumbnail = page.thumbnail(of: thumbSize, for: .mediaBox)

        guard let cgImage = thumbnail.cgImage(forProposedRect: nil, context: nil, hints: nil) else { continue }

        let semaphore = DispatchSemaphore(value: 0)
        var pageText = ""

        let request = VNRecognizeTextRequest { req, _ in
            let observations = req.results as? [VNRecognizedTextObservation] ?? []
            pageText = observations
                .compactMap { $0.topCandidates(1).first?.string }
                .joined(separator: "\n")
            semaphore.signal()
        }
        request.recognitionLevel = .accurate
        request.recognitionLanguages = ["ko-KR", "en-US"]
        request.usesLanguageCorrection = true

        try? VNImageRequestHandler(cgImage: cgImage, options: [:]).perform([request])
        semaphore.wait()

        if !pageText.isEmpty {
            result += "=== Page \(pageIndex + 1) ===\n\(pageText)\n\n"
        }
    }
    return result
}

guard CommandLine.arguments.count > 1 else {
    fputs("Usage: swift extract_pdf.swift <pdf_path>\n", stderr)
    exit(1)
}

let path = CommandLine.arguments[1]
let url = URL(fileURLWithPath: path)

guard FileManager.default.fileExists(atPath: path) else {
    fputs("Error: File not found at \(path)\n", stderr)
    exit(1)
}

// 텍스트 레이어 우선 시도, 없으면 OCR
if let text = extractWithPDFKit(url: url) {
    print(text)
} else {
    fputs("[INFO] 텍스트 레이어 없음 — Vision OCR로 재시도합니다...\n", stderr)
    let ocrText = extractWithVisionOCR(url: url)
    if ocrText.isEmpty {
        fputs("Error: 텍스트를 추출할 수 없습니다.\n", stderr)
        exit(1)
    }
    print(ocrText)
}
