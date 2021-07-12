package config

import (
	"fmt"

	"github.com/spf13/viper"
)

const (
	DefaultConfigFileName = "./config/config.yaml"

	ConfigKeyAppChainType = "base.app_chain_type"
	ConfigKeyStorePath    = "base.store_path"

	ConfigKeyHttpPort = "base.http_port"

	DefaultStorePath = ".db"
)

// LoadYAMLConfig loads the YAML config file
func LoadYAMLConfig(configFileName string) (*viper.Viper, error) {
	v := viper.New()

	v.SetConfigFile(configFileName)
	v.SetConfigType("yaml")

	err := v.ReadInConfig()
	if err != nil {
		return nil, fmt.Errorf("failed to read the config file: %s", err)
	}

	return v, nil
}

// GetConfigKey returns the key with the given prefix
func GetConfigKey(prefix string, key string) string {
	return fmt.Sprintf("%s.%s", prefix, key)
}
