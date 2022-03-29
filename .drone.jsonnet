local KANIKO_TAG="15";

local registry = "waicosnovadi.azurecr.io";
local docker_username = "waicosnovadi";

###############################################################################
local pipeline(name) = {
    name: name,
    kind: "pipeline",
    type: "kubernetes",
    node_selector: {
        "agentpool": "agents2"
    },
    volumes: [
        {name: "cache",   temp: {}},
    ],
};

local teams() = {
    name: "teams-webhook",
    image: "jdamata/drone-teams",
    settings: {
        webhook: "https://cosnova.webhook.office.com/webhookb2/33d531bc-5376-4c05-91f8-2c702d0e4fb5@89094d94-eae9-44db-9767-7fd72e6191e5/IncomingWebhook/e99cd0c63c7248c388658282b93bc601/0763258b-31a7-4302-8988-37a5ebc6916d"
    },
};

local kaniko(name, artifact, context, dockerfile, list) = {
    name: name,
    image: "wunderai/drone-kaniko:%s" % [KANIKO_TAG],
    pull: "if-not-exists",
    volumes: [ 
      {name: "cache", path: "/cache"}, 
    ],
    environment: {
        GITHUB_ACCESS_TOKEN: {from_secret: "GITHUB_ACCESS_TOKEN"},
    },
    settings: {
        context: context,
        auto_tag: true,
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
        password: { from_secret: "docker_password"},

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
            '/kaniko/plugin.sh',
            # '/slack', # disable slack in case of success - too noisy
        ]),
        teams(),
        kaniko("report-failure", artifact, ".", "Dockerfile", [
            'PLUGIN_SLACK_TEMPLATE=$PLUGIN_SLACK_TEMPLATE_FAILURE /slack',
        ]) + {when: {status:["failure"]},},
    ],
};

local buildCtx(artifact, directory) = pipeline(artifact) {
    trigger: { event: ["push", "tag", "cron"] },
    steps: [
        kaniko("build", artifact, directory, "%s/Dockerfile" % [directory], [
            '/kaniko/plugin.sh',
            # '/slack',
        ]),
        teams(),
        kaniko("report-failure", artifact, directory, "Dockerfile", [
            'PLUGIN_SLACK_TEMPLATE=$PLUGIN_SLACK_TEMPLATE_FAILURE /slack',
        ]) + {when: {status:["failure"]},},
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
  k8sSecret("docker_password", "drone-env-secrets-cosnova", "COSNOVA_DI_ACR_ADMIN_PASSWORD"),
  k8sSecret("slack_token", "drone-env-secrets-cosnova", "SLACK_TOKEN"),
  
  build('datafetch-jobs', 'datafetch/source'),
  #build('pgadmin', 'source/pgadmin-test'),
  build('lamashop-datafetch','source/lamashop') ,
  build('consentmanager-datafetch','source/consentmanager/datafetch')  ,
  build('consentmanager-dataprep','source/consentmanager/dataprep')  ,
  build('commerceconnector-datafetch','source/CommerceConnector') ,
  build('commerceconnector-backfill','source/CommerceConnectorBackfill') ,
  build('amzn-ads-datafetch','source/AmazonAds') ,

]
###############################################################################
