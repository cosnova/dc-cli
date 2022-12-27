local registry = "cnvwebshop.azurecr.io";
local docker_username = "cnvwebshop";

###############################################################################
local pipeline(name) = {
    name: name,
    kind: "pipeline",
    type: "kubernetes",
    node_selector: {
        "agentpool": "agents"
    },
    volumes: [
        {name: "cache",   temp: {}},
    ],
};

local kaniko(name, artifact, context, dockerfile, list) = {
    name: name,
    image: "cnvtools.azurecr.io/drone-kaniko:main-prod",
    pull: "if-not-exists",
    volumes: [ 
      {name: "cache", path: "/cache"}, 
    ],
    environment: {
        GITHUB_ACCESS_TOKEN: {from_secret: "GITHUB_ACCESS_TOKEN"},
    },
    settings: {
        context: context,
        auto_tag: false,
        auto_tag_suffix: "${DRONE_BRANCH}", # generates tags like 1.0.1-master, 1.0-master, 1-master
        tags: ["${DRONE_BRANCH}","${DRONE_COMMIT_SHA:0:8}"],
        cache: true,
        cache_dir: "/cache",
        debug: true,
        dockerfile: dockerfile,
        registry: registry,
        #repo: artifact,
        destinationPrefix: registry,
        repo: "%s/%s" % [registry, artifact],
        build_args: [
            "BASE_TAG=${DRONE_COMMIT_SHA:0:8}",
        #    "REPO=${DRONE_REPO}",
            "COMMIT_BRANCH=${DRONE_COMMIT_BRANCH}",
        #    "COMMIT_SHA=${DRONE_COMMIT_SHA}",
        #    "COMMIT_AUTHOR_EMAIL=${DRONE_COMMIT_AUTHOR_EMAIL}",
        #    "BUILD_LINK=${DRONE_BUILD_LINK}",
        ],
        username: docker_username,
        password: { from_secret: "registry_webshop"},

        slack_token: { from_secret: "slack_token" },
        slack_channel: "github-cosnova-di",
        slack_username: "drone",
        slack_template: "{{build.Status}} <https://github.com/{{repo.Owner}}/{{repo.Name}}/commit/{{build.Commit}}|{{truncate build.Commit 8}}> in <https://github.com/{{repo.Owner}}/{{repo.Name}}/tree/{{build.Branch}}|{{build.Branch}}> by <@{{build.Author}}> published %s/%s {{build.Branch}}-{{build.Number}}" % [registry, artifact],
        slack_template_failure: "{{build.Status}} <https://github.com/{{repo.Owner}}/{{repo.Name}}/commit/{{build.Commit}}|{{truncate build.Commit 8}}> in <https://github.com/{{repo.Owner}}/{{repo.Name}}/tree/{{build.Branch}}|{{build.Branch}}> by <@{{build.Author}}> %s {{build.Branch}}-{{build.Number}}" % [artifact],
    },
    commands: list,
};

local build(artifact, directory) = pipeline(artifact) {
    trigger: { event: ["push", "tag", "cron"] },
    steps: [
        kaniko("build", artifact, ".", "%s/Dockerfile" % [directory], [
            'mv /_kaniko /kaniko',           
            '/kaniko/plugin.sh',
            # '/slack', # disable slack in case of success - too noisy
        ]),
    ],
};

local k8sSecret(name, path, key) = {
    kind: "secret",
    name: name,
    get: {
          path: path,
          name: key,
      }
};

###############################################################################
[
  #k8sSecret("docker_password", "drone-env-secrets", "COSNOVA_DI_ACR_ADMIN_PASSWORD"),
  #k8sSecret("slack_token", "drone-env-secrets", "SLACK_TOKEN"),
  k8sSecret("cnvtools", "cnvtools", ".dockerconfigjson"),  

  build('dc-cli', ''),


]
###############################################################################
