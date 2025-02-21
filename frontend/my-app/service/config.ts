import config from '@/public/config.json';

interface Config {
  cognito: {
    userPoolId: string;
    clientId: string;
  };
  api: {
    backendUrl: string;
  };
}

class ConfigService {
  private static instance: ConfigService;
  private config: Config;

  private constructor() {
    this.config = config;
  }

  public static getInstance(): ConfigService {
    if (!ConfigService.instance) {
      ConfigService.instance = new ConfigService();
    }
    return ConfigService.instance;
  }

  public get(): Config {
    return this.config;
  }
}

export const configService = ConfigService.getInstance(); 