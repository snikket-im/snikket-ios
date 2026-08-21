import CryptoKit
import Darwin
import Foundation

let apiRoot = "https://api.appstoreconnect.apple.com"
let bundleID = "org.snikket.ios"

enum ConnectError: LocalizedError {
  case message(String)

  var errorDescription: String? {
    switch self {
    case .message(let value):
      return value
    }
  }
}

struct Credentials {
  let keyPath: URL
  let keyID: String
  let issuerID: String
}

func credentials() throws -> Credentials {
  let environment = ProcessInfo.processInfo.environment
  let names = ["ASC_KEY_PATH", "ASC_KEY_ID", "ASC_ISSUER_ID"]
  let missing = names.filter { environment[$0, default: ""].isEmpty }
  guard missing.isEmpty else {
    throw ConnectError.message(
      "missing App Store Connect setting(s): " + missing.joined(separator: ", ")
    )
  }

  let rawPath = NSString(string: environment["ASC_KEY_PATH"]!).expandingTildeInPath
  let path: URL
  if rawPath.hasPrefix("/") {
    path = URL(fileURLWithPath: rawPath)
  } else {
    path = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
      .appendingPathComponent(rawPath)
  }
  let normalizedPath = path.standardizedFileURL
  guard FileManager.default.fileExists(atPath: normalizedPath.path) else {
    throw ConnectError.message(
      "App Store Connect private key not found: \(normalizedPath.path)"
    )
  }
  return Credentials(
    keyPath: normalizedPath,
    keyID: environment["ASC_KEY_ID"]!,
    issuerID: environment["ASC_ISSUER_ID"]!
  )
}

func base64URL(_ data: Data) -> String {
  data.base64EncodedString()
    .replacingOccurrences(of: "+", with: "-")
    .replacingOccurrences(of: "/", with: "_")
    .replacingOccurrences(of: "=", with: "")
}

func makeToken() throws -> String {
  let values = try credentials()
  let now = Int(Date().timeIntervalSince1970)
  let header: [String: Any] = [
    "alg": "ES256",
    "kid": values.keyID,
    "typ": "JWT",
  ]
  let payload: [String: Any] = [
    "iss": values.issuerID,
    "iat": now,
    "exp": now + 1_200,
    "aud": "appstoreconnect-v1",
  ]
  let encodedHeader = base64URL(
    try JSONSerialization.data(withJSONObject: header, options: [.sortedKeys])
  )
  let encodedPayload = base64URL(
    try JSONSerialization.data(withJSONObject: payload, options: [.sortedKeys])
  )
  let signingInput = Data("\(encodedHeader).\(encodedPayload)".utf8)

  do {
    let pem = try String(contentsOf: values.keyPath, encoding: .utf8)
    let privateKey = try P256.Signing.PrivateKey(pemRepresentation: pem)
    let signature = try privateKey.signature(for: signingInput)
    return "\(encodedHeader).\(encodedPayload).\(base64URL(signature.rawRepresentation))"
  } catch {
    throw ConnectError.message(
      "could not load or use private key at \(values.keyPath.path)"
    )
  }
}

func dictionary(_ value: Any?) -> [String: Any] {
  value as? [String: Any] ?? [:]
}

func dictionaries(_ value: Any?) -> [[String: Any]] {
  value as? [[String: Any]] ?? []
}

func apiRequest(
  _ method: String, _ pathOrURL: String
) async throws -> [String: Any]? {
  let value = pathOrURL.hasPrefix("https://") ? pathOrURL : apiRoot + pathOrURL
  guard let url = URL(string: value) else {
    throw ConnectError.message("invalid App Store Connect URL")
  }
  var request = URLRequest(url: url, timeoutInterval: 30)
  request.httpMethod = method
  request.setValue("Bearer \(try makeToken())", forHTTPHeaderField: "Authorization")
  request.setValue("application/json", forHTTPHeaderField: "Accept")
  request.setValue("snikket-ios-release-script/1", forHTTPHeaderField: "User-Agent")

  let data: Data
  let response: URLResponse
  do {
    (data, response) = try await URLSession.shared.data(for: request)
  } catch let error as URLError {
    throw ConnectError.message(
      "could not reach App Store Connect: \(error.localizedDescription)"
    )
  }
  guard let http = response as? HTTPURLResponse else {
    throw ConnectError.message("App Store Connect returned an invalid response")
  }
  guard (200..<300).contains(http.statusCode) else {
    let body = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
    let details = dictionaries(body?["errors"]).compactMap { item in
      item["detail"] as? String ?? item["title"] as? String
    }
    let suffix = details.isEmpty ? "" : ": " + details.joined(separator: "; ")
    throw ConnectError.message(
      "App Store Connect returned HTTP \(http.statusCode)\(suffix)"
    )
  }
  if data.isEmpty {
    return nil
  }
  guard let result = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
    throw ConnectError.message("App Store Connect returned invalid JSON")
  }
  return result
}

func apiGet(_ pathOrURL: String) async throws -> [String: Any] {
  guard let result = try await apiRequest("GET", pathOrURL) else {
    throw ConnectError.message("App Store Connect returned an empty response")
  }
  return result
}

func apiDelete(_ path: String) async throws {
  _ = try await apiRequest("DELETE", path)
}

func endpoint(_ path: String, queryItems: [URLQueryItem]) throws -> String {
  var components = URLComponents(string: apiRoot + path)
  components?.queryItems = queryItems
  guard let url = components?.url else {
    throw ConnectError.message("could not construct App Store Connect request")
  }
  return url.absoluteString
}

func appID() async throws -> String {
  let url = try endpoint(
    "/v1/apps",
    queryItems: [
      URLQueryItem(name: "filter[bundleId]", value: bundleID),
      URLQueryItem(name: "limit", value: "1"),
    ]
  )
  let response = try await apiGet(url)
  guard let id = dictionaries(response["data"]).first?["id"] as? String else {
    throw ConnectError.message("no App Store Connect app found for \(bundleID)")
  }
  return id
}

func buildUploads() async throws -> [[String: Any]] {
  let id = try await appID()
  var nextURL: String? = try endpoint(
    "/v1/apps/\(id)/buildUploads",
    queryItems: [
      URLQueryItem(name: "filter[platform]", value: "IOS"),
      URLQueryItem(
        name: "fields[buildUploads]",
        value: "cfBundleShortVersionString,cfBundleVersion,createdDate,state,uploadedDate"
      ),
      URLQueryItem(name: "sort", value: "-uploadedDate"),
      URLQueryItem(name: "limit", value: "200"),
    ]
  )
  var result: [[String: Any]] = []
  while let url = nextURL {
    let response = try await apiGet(url)
    result.append(contentsOf: dictionaries(response["data"]))
    nextURL = dictionary(response["links"])["next"] as? String
  }
  return result
}

struct TestFlightBuild {
  let id: String
  let version: String
  let build: String
  let state: String
  let uploadedDate: String
  let expired: Bool
  let expirationDate: String
}

func testFlightBuilds() async throws -> [TestFlightBuild] {
  let id = try await appID()
  var nextURL: String? = try endpoint(
    "/v1/builds",
    queryItems: [
      URLQueryItem(name: "filter[app]", value: id),
      URLQueryItem(name: "filter[preReleaseVersion.platform]", value: "IOS"),
      URLQueryItem(
        name: "fields[builds]",
        value: "version,uploadedDate,processingState,expired,expirationDate,preReleaseVersion"
      ),
      URLQueryItem(name: "fields[preReleaseVersions]", value: "version,platform"),
      URLQueryItem(name: "include", value: "preReleaseVersion"),
      URLQueryItem(name: "sort", value: "-uploadedDate"),
      URLQueryItem(name: "limit", value: "200"),
    ]
  )
  var result: [TestFlightBuild] = []
  while let url = nextURL {
    let response = try await apiGet(url)
    let versions: [String: String] = Dictionary(
      uniqueKeysWithValues: dictionaries(response["included"]).compactMap { item in
        guard item["type"] as? String == "preReleaseVersions",
          let id = item["id"] as? String,
          let version = dictionary(item["attributes"])["version"] as? String
        else {
          return nil
        }
        return (id, version)
      }
    )
    for build in dictionaries(response["data"]) {
      let buildAttributes = dictionary(build["attributes"])
      let relationships = dictionary(build["relationships"])
      let preReleaseVersion = dictionary(relationships["preReleaseVersion"])
      let versionData = dictionary(preReleaseVersion["data"])
      let versionID = versionData["id"] as? String ?? ""
      result.append(
        TestFlightBuild(
          id: build["id"] as? String ?? "",
          version: versions[versionID] ?? "UNKNOWN",
          build: buildAttributes["version"] as? String ?? "",
          state: buildAttributes["processingState"] as? String ?? "UNKNOWN",
          uploadedDate: buildAttributes["uploadedDate"] as? String ?? "",
          expired: buildAttributes["expired"] as? Bool ?? false,
          expirationDate: buildAttributes["expirationDate"] as? String ?? ""
        )
      )
    }
    nextURL = dictionary(response["links"])["next"] as? String
  }
  return result
}

struct AppStoreVersion {
  let version: String
  let state: String
  let buildNumber: String
}

let inFlightAppStoreStates: Set<String> = [
  "PREPARE_FOR_SUBMISSION", "PROCESSING_FOR_APP_STORE", "WAITING_FOR_REVIEW",
  "IN_REVIEW", "PENDING_DEVELOPER_RELEASE", "PENDING_APPLE_RELEASE", "ACCEPTED",
  "DEVELOPER_REJECTED", "REJECTED", "METADATA_REJECTED", "INVALID_BINARY",
]

func appStoreVersions() async throws -> [AppStoreVersion] {
  let id = try await appID()
  let url = try endpoint(
    "/v1/apps/\(id)/appStoreVersions",
    queryItems: [
      URLQueryItem(name: "filter[platform]", value: "IOS"),
      URLQueryItem(name: "fields[appStoreVersions]", value: "versionString,appStoreState,build"),
      URLQueryItem(name: "fields[builds]", value: "version"),
      URLQueryItem(name: "include", value: "build"),
      URLQueryItem(name: "limit", value: "20"),
    ]
  )
  let response = try await apiGet(url)
  let buildNumbers: [String: String] = Dictionary(
    uniqueKeysWithValues: dictionaries(response["included"]).compactMap { item in
      guard item["type"] as? String == "builds",
        let id = item["id"] as? String,
        let number = dictionary(item["attributes"])["version"] as? String
      else {
        return nil
      }
      return (id, number)
    }
  )
  return dictionaries(response["data"]).map { item in
    let attributes = dictionary(item["attributes"])
    let buildData = dictionary(dictionary(dictionary(item["relationships"])["build"])["data"])
    return AppStoreVersion(
      version: attributes["versionString"] as? String ?? "",
      state: attributes["appStoreState"] as? String
        ?? attributes["appVersionState"] as? String ?? "UNKNOWN",
      buildNumber: buildNumbers[buildData["id"] as? String ?? ""] ?? ""
    )
  }
}

func betaGroupNames(ofBuild buildID: String) async throws -> [String] {
  // The build -> betaGroups relationship rejects related-resource GETs, so
  // fetch the build itself with the groups included.
  let url = try endpoint(
    "/v1/builds/\(buildID)",
    queryItems: [
      URLQueryItem(name: "include", value: "betaGroups"),
      URLQueryItem(name: "fields[builds]", value: "betaGroups"),
      URLQueryItem(name: "fields[betaGroups]", value: "name"),
    ]
  )
  return dictionaries(try await apiGet(url)["included"]).compactMap { item in
    guard item["type"] as? String == "betaGroups" else {
      return nil
    }
    return dictionary(item["attributes"])["name"] as? String
  }
}

func externalBuildState(ofBuild buildID: String) async throws -> String {
  let url = try endpoint(
    "/v1/builds/\(buildID)/buildBetaDetail",
    queryItems: [
      URLQueryItem(name: "fields[buildBetaDetails]", value: "externalBuildState")
    ]
  )
  let data = dictionary(try await apiGet(url)["data"])
  return dictionary(data["attributes"])["externalBuildState"] as? String ?? "UNKNOWN"
}

func attributes(_ upload: [String: Any]) -> [String: Any] {
  dictionary(upload["attributes"])
}

func stringAttribute(_ name: String, of upload: [String: Any]) -> String {
  attributes(upload)[name] as? String ?? ""
}

func stateName(_ upload: [String: Any]) -> String {
  let value = attributes(upload)["state"]
  if let state = value as? String {
    return state
  }
  return dictionary(value)["state"] as? String ?? "UNKNOWN"
}

func resourceID(_ resource: [String: Any]) -> String {
  resource["id"] as? String ?? ""
}

func parseDate(_ value: String) -> Date? {
  let fractional = ISO8601DateFormatter()
  fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
  if let date = fractional.date(from: value) {
    return date
  }
  return ISO8601DateFormatter().date(from: value)
}

func createdDate(_ upload: [String: Any]) -> Date? {
  parseDate(stringAttribute("createdDate", of: upload))
}

func day(_ isoDate: String) -> String {
  isoDate.count >= 10 ? String(isoDate.prefix(10)) : isoDate
}

func compareVersions(_ left: String, _ right: String) -> Int {
  let leftParts = left.split(separator: ".").map { Int($0) ?? 0 }
  let rightParts = right.split(separator: ".").map { Int($0) ?? 0 }
  for index in 0..<max(leftParts.count, rightParts.count) {
    let leftValue = index < leftParts.count ? leftParts[index] : 0
    let rightValue = index < rightParts.count ? rightParts[index] : 0
    if leftValue != rightValue {
      return leftValue < rightValue ? -1 : 1
    }
  }
  return 0
}

func matchingUploads(
  _ uploads: [[String: Any]], version: String, build: String
) -> [[String: Any]] {
  uploads.filter {
    stringAttribute("cfBundleShortVersionString", of: $0) == version
      && stringAttribute("cfBundleVersion", of: $0) == build
  }
}

func printBuildsTable(_ builds: [TestFlightBuild]) {
  print("VERSION\tBUILD\tSTATE\tEXPIRED\tUPLOADED")
  for build in builds {
    print(
      [
        build.version,
        build.build,
        build.state,
        build.expired ? "yes" : "no",
        build.uploadedDate,
      ].joined(separator: "\t")
    )
  }
}

func listBuilds() async throws {
  printBuildsTable(try await testFlightBuilds())
}

func listUploads() async throws {
  print("ID\tVERSION\tBUILD\tSTATE\tCREATED\tUPLOADED")
  for upload in try await buildUploads() {
    print(
      [
        resourceID(upload),
        stringAttribute("cfBundleShortVersionString", of: upload),
        stringAttribute("cfBundleVersion", of: upload),
        stateName(upload),
        stringAttribute("createdDate", of: upload),
        stringAttribute("uploadedDate", of: upload),
      ].joined(separator: "\t")
    )
  }
}

func appendBuildNumber(
  _ value: String, to numbers: inout [Int], invalid: inout Set<String>
) {
  if let number = Int(value), number >= 0 {
    numbers.append(number)
  } else if !value.isEmpty {
    invalid.insert(value)
  }
}

func nextBuildNumber(
  builds: [TestFlightBuild], uploads: [[String: Any]]
) throws -> Int {
  var numbers: [Int] = []
  var invalid: Set<String> = []
  for build in builds {
    appendBuildNumber(build.build, to: &numbers, invalid: &invalid)
  }
  let recentCutoff = Date().addingTimeInterval(-24 * 60 * 60)
  for upload in uploads {
    let state = stateName(upload)
    let shouldReserveNumber =
      state == "COMPLETE"
      || state == "PROCESSING"
      || (state == "AWAITING_UPLOAD" && (createdDate(upload) ?? .distantPast) >= recentCutoff)
    if shouldReserveNumber {
      appendBuildNumber(
        stringAttribute("cfBundleVersion", of: upload),
        to: &numbers,
        invalid: &invalid
      )
    }
  }
  guard invalid.isEmpty else {
    throw ConnectError.message(
      "cannot choose a safe next build: non-integer historical build number(s): "
        + invalid.sorted().joined(separator: ", ")
    )
  }
  return (numbers.max() ?? 0) + 1
}

func nextBuildNumber() async throws -> Int {
  try nextBuildNumber(builds: await testFlightBuilds(), uploads: await buildUploads())
}

func printStatus(showAll: Bool) async throws {
  let builds = try await testFlightBuilds()
  let uploads = try await buildUploads()
  let versions = try await appStoreVersions()

  let live = versions.first { $0.state == "READY_FOR_SALE" }
  if let live {
    let buildSuffix = live.buildNumber.isEmpty ? "" : " (\(live.buildNumber))"
    print("App Store: \(live.version)\(buildSuffix) READY_FOR_SALE")
  } else {
    print("App Store: no released version found")
  }
  for version in versions where inFlightAppStoreStates.contains(version.state) {
    print("App Store: \(version.version) \(version.state)")
  }

  let testable = builds.filter { !$0.expired }
  print("")
  if testable.isEmpty {
    if let newest = builds.first {
      print(
        "TestFlight: no testable builds "
          + "(newest: \(newest.version) (\(newest.build)), expired \(day(newest.expirationDate)))"
      )
    } else {
      print("TestFlight: no builds uploaded")
    }
  } else {
    print("TestFlight:")
    for build in testable {
      var line = "  \(build.version) (\(build.build))  \(build.state)  uploaded \(day(build.uploadedDate))"
      if !build.expirationDate.isEmpty {
        line += ", expires \(day(build.expirationDate))"
      }
      print(line)
      let groups = try await betaGroupNames(ofBuild: build.id)
      let external = try await externalBuildState(ofBuild: build.id)
      let groupText = groups.isEmpty ? "none" : groups.joined(separator: ", ")
      print("    groups: \(groupText) (external state: \(external))")
    }
  }

  let pending = uploads.filter { stateName($0) != "COMPLETE" }
  if pending.isEmpty {
    print("\nNo pending upload operations.")
  } else {
    print("\nPending upload operations:")
    print("ID\tVERSION\tBUILD\tSTATE\tCREATED")
    for upload in pending {
      print(
        [
          resourceID(upload),
          stringAttribute("cfBundleShortVersionString", of: upload),
          stringAttribute("cfBundleVersion", of: upload),
          stateName(upload),
          stringAttribute("createdDate", of: upload),
        ].joined(separator: "\t")
      )
    }
  }

  print("\nNext build number: \(try nextBuildNumber(builds: builds, uploads: uploads))")

  let local = ProcessInfo.processInfo.environment["SNIKKET_LOCAL_VERSION"] ?? ""
  if !local.isEmpty {
    if let live {
      let comparison = compareVersions(local, live.version)
      if comparison == 0 {
        print(
          "Local version: \(local) — matches the App Store release; TestFlight can take "
            + "more \(local) builds, but an App Store release needs a higher version"
        )
      } else if comparison < 0 {
        print(
          "Local version: \(local) — OLDER than the App Store release \(live.version); "
            + "run 'version set'"
        )
      } else {
        print("Local version: \(local) — ahead of the App Store release \(live.version)")
      }
    } else {
      print("Local version: \(local)")
    }
  }

  if showAll {
    print("\nAll builds:")
    printBuildsTable(builds)
  }
}

func currentState(version: String, build: String) async throws -> String {
  let matches = matchingUploads(
    try await buildUploads(), version: version, build: build
  )
  if matches.contains(where: { stateName($0) == "COMPLETE" }) {
    return "COMPLETE"
  }
  let newest = matches.max { left, right in
    (createdDate(left) ?? .distantPast) < (createdDate(right) ?? .distantPast)
  }
  return newest.map(stateName) ?? "NOT_FOUND"
}

func option(_ name: String, in arguments: [String]) throws -> String {
  guard let index = arguments.firstIndex(of: name), index + 1 < arguments.count else {
    throw ConnectError.message("missing required option \(name)")
  }
  return arguments[index + 1]
}

func integerOption(
  _ name: String, in arguments: [String], default defaultValue: Int
) throws -> Int {
  guard let index = arguments.firstIndex(of: name) else {
    return defaultValue
  }
  guard index + 1 < arguments.count,
    let value = Int(arguments[index + 1]),
    value > 0
  else {
    throw ConnectError.message("\(name) must be a positive integer")
  }
  return value
}

func validateOptions(_ arguments: [String], pairs: Set<String>) throws {
  var index = 0
  while index < arguments.count {
    let argument = arguments[index]
    guard pairs.contains(argument), index + 1 < arguments.count else {
      throw ConnectError.message("unknown or incomplete option: \(argument)")
    }
    index += 2
  }
}

func testFlightCrashSubmissions(arguments: [String]) async throws {
  try validateOptions(arguments, pairs: ["--limit"])
  let limit = try integerOption("--limit", in: arguments, default: 50)
  guard limit <= 200 else {
    throw ConnectError.message("--limit must not exceed 200")
  }

  let id = try await appID()
  let url = try endpoint(
    "/v1/apps/\(id)/betaFeedbackCrashSubmissions",
    queryItems: [
      URLQueryItem(
        name: "fields[betaFeedbackCrashSubmissions]",
        value: "createdDate,deviceModel,osVersion,architecture,appPlatform,devicePlatform,deviceFamily,buildBundleId,build"
      ),
      URLQueryItem(name: "fields[builds]", value: "version"),
      URLQueryItem(name: "include", value: "build"),
      URLQueryItem(name: "sort", value: "-createdDate"),
      URLQueryItem(name: "limit", value: String(limit)),
    ]
  )
  let response = try await apiGet(url)
  let submissions = dictionaries(response["data"])
  guard !submissions.isEmpty else {
    print("No TestFlight crash feedback submissions found.")
    return
  }

  var buildVersions: [String: String] = [:]
  for item in dictionaries(response["included"])
  where item["type"] as? String == "builds" {
    guard let buildID = item["id"] as? String else { continue }
    buildVersions[buildID] = dictionary(item["attributes"])["version"] as? String
  }

  print("TestFlight crash feedback: \(submissions.count)")
  for submission in submissions {
    let attributes = dictionary(submission["attributes"])
    let relationships = dictionary(submission["relationships"])
    let buildRelationship = dictionary(relationships["build"])
    let buildData = dictionary(buildRelationship["data"])
    let buildID = buildData["id"] as? String ?? ""
    let submitted = attributes["createdDate"] as? String ?? "unknown"
    let device = attributes["deviceModel"] as? String
      ?? attributes["deviceFamily"] as? String
      ?? "unknown device"
    let osVersion = attributes["osVersion"] as? String ?? "unknown OS"
    let architecture = attributes["architecture"] as? String ?? "unknown architecture"
    let build = buildVersions[buildID] ?? "unknown"
    let submissionID = submission["id"] as? String ?? "unknown"

    print("\n  ID: \(submissionID)")
    print("  Submitted: \(submitted)")
    print("  Build: \(build)")
    print("  Device: \(device), \(osVersion), \(architecture)")
  }
  print("\nTester email and comments are intentionally omitted.")
}

func downloadTestFlightCrashLog(arguments: [String]) async throws {
  try validateOptions(arguments, pairs: ["--id", "--output"])
  let id = try option("--id", in: arguments)
  let output = try option("--output", in: arguments)
  guard id.range(of: "^[A-Za-z0-9-]+$", options: .regularExpression) != nil else {
    throw ConnectError.message("crash submission ID contains unexpected characters")
  }

  let url = try endpoint(
    "/v1/betaFeedbackCrashSubmissions/\(id)/crashLog",
    queryItems: [URLQueryItem(name: "fields[betaCrashLogs]", value: "logText")]
  )
  let response = try await apiGet(url)
  let data = dictionary(response["data"])
  let attributes = dictionary(data["attributes"])
  guard let log = attributes["logText"] as? String, !log.isEmpty else {
    throw ConnectError.message("App Store Connect returned no crash log text")
  }

  let outputURL = URL(fileURLWithPath: output, relativeTo: URL(fileURLWithPath: FileManager.default.currentDirectoryPath))
    .standardizedFileURL
  try FileManager.default.createDirectory(
    at: outputURL.deletingLastPathComponent(),
    withIntermediateDirectories: true
  )
  try log.write(to: outputURL, atomically: true, encoding: .utf8)
  print("Saved TestFlight crash log: \(outputURL.path)")
}

func cleanupUploads(arguments: [String]) async throws {
  let hours = try integerOption("--older-than", in: arguments, default: 24)
  let dryRun = arguments.contains("--dry-run")
  let confirmed = arguments.contains("--yes")
  let allowed = Set(["--older-than", "--dry-run", "--yes"])
  var index = 0
  while index < arguments.count {
    let argument = arguments[index]
    guard allowed.contains(argument) else {
      throw ConnectError.message("unknown cleanup option: \(argument)")
    }
    index += argument == "--older-than" ? 2 : 1
  }
  guard !(dryRun && confirmed) else {
    throw ConnectError.message("--dry-run and --yes cannot be used together")
  }

  let cutoff = Date().addingTimeInterval(-TimeInterval(hours) * 60 * 60)
  let candidates = try await buildUploads().filter { upload in
    stateName(upload) == "AWAITING_UPLOAD"
      && (createdDate(upload) ?? .distantFuture) <= cutoff
  }
  guard !candidates.isEmpty else {
    print("No AWAITING_UPLOAD reservations are older than \(hours) hours.")
    return
  }

  print("ID\tVERSION\tBUILD\tCREATED")
  for upload in candidates {
    print(
      [
        resourceID(upload),
        stringAttribute("cfBundleShortVersionString", of: upload),
        stringAttribute("cfBundleVersion", of: upload),
        stringAttribute("createdDate", of: upload),
      ].joined(separator: "\t")
    )
  }
  if dryRun {
    print("Dry run: would delete \(candidates.count) stale upload reservation(s).")
    return
  }
  if !confirmed {
    guard isatty(STDIN_FILENO) != 0 else {
      throw ConnectError.message(
        "cleanup needs an interactive terminal, --dry-run, or --yes"
      )
    }
    print("Delete these \(candidates.count) stale upload reservation(s)? [y/N] ", terminator: "")
    fflush(stdout)
    let answer = readLine()?.lowercased() ?? ""
    guard ["y", "yes"].contains(answer) else {
      throw ConnectError.message("cleanup cancelled")
    }
  }

  for upload in candidates {
    let id = resourceID(upload)
    guard !id.isEmpty else {
      throw ConnectError.message("App Store Connect returned an upload without an ID")
    }
    try await apiDelete("/v1/buildUploads/\(id)")
    print("Deleted \(id)")
  }
  print("Deleted \(candidates.count) stale upload reservation(s).")
}

func waitForUpload(arguments: [String]) async throws {
  let version = try option("--version", in: arguments)
  let build = try option("--build", in: arguments)
  let timeout = try integerOption("--timeout", in: arguments, default: 1_800)
  let interval = try integerOption("--interval", in: arguments, default: 30)
  let deadline = Date().addingTimeInterval(TimeInterval(timeout))
  var lastState = ""

  while true {
    let state = try await currentState(version: version, build: build)
    if state != lastState {
      print("TestFlight upload \(version) (\(build)): \(state)")
      fflush(stdout)
      lastState = state
    }
    if state == "COMPLETE" {
      return
    }
    if state == "FAILED" {
      throw ConnectError.message(
        "TestFlight reports upload \(version) (\(build)) as FAILED"
      )
    }
    if Date() >= deadline {
      throw ConnectError.message(
        "timed out waiting for upload \(version) (\(build)); last state was \(state)"
      )
    }
    try await Task.sleep(nanoseconds: UInt64(interval) * 1_000_000_000)
  }
}

func usage() {
  print(
    """
    Usage: app-store-connect COMMAND [OPTIONS]

      status [--all]                 Show App Store, TestFlight, and next-build state
      status --version V --build N   Print one upload's current state
      builds                         List processed iOS TestFlight builds
      uploads                        List raw iOS build upload operations
      testflight-crashes [--limit N] List redacted TestFlight crash feedback
      testflight-crash-log OPTIONS   Save one TestFlight crash log to a file
      cleanup [OPTIONS]              Delete stale AWAITING_UPLOAD reservations
      next-build                     Print the next global integer build number
      wait --version V --build N     Wait for an upload to finish processing
    """
  )
}

@main
struct AppStoreConnectClient {
  static func main() async {
    let arguments = Array(CommandLine.arguments.dropFirst())
    guard let command = arguments.first else {
      usage()
      exit(2)
    }
    let options = Array(arguments.dropFirst())
    do {
      switch command {
      case "builds":
        try await listBuilds()
      case "uploads":
        try await listUploads()
      case "testflight-crashes":
        try await testFlightCrashSubmissions(arguments: options)
      case "testflight-crash-log":
        try await downloadTestFlightCrashLog(arguments: options)
      case "cleanup":
        try await cleanupUploads(arguments: options)
      case "next-build":
        print(try await nextBuildNumber())
      case "status":
        if options.isEmpty {
          try await printStatus(showAll: false)
        } else if options == ["--all"] {
          try await printStatus(showAll: true)
        } else {
          print(
            try await currentState(
              version: option("--version", in: options),
              build: option("--build", in: options)
            )
          )
        }
      case "wait":
        try await waitForUpload(arguments: options)
      case "help", "-h", "--help":
        usage()
      default:
        throw ConnectError.message("unknown command: \(command)")
      }
    } catch {
      fputs("error: \(error.localizedDescription)\n", stderr)
      exit(1)
    }
  }
}
