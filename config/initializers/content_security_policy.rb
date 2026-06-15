# Be sure to restart your server when you modify this file.

# Define an application-wide content security policy.
# See the Securing Rails Applications Guide for more information:
# https://guides.rubyonrails.org/security.html#content-security-policy-header
#
# All assets are first-party (one linked stylesheet, no inline/remote JS), so a
# strict same-origin policy applies cleanly. Enforced everywhere except
# development, where it runs report-only so web-console's inline scripts work.
Rails.application.configure do
  config.content_security_policy do |policy|
    policy.default_src     :self
    policy.font_src        :self
    policy.img_src         :self, :data
    policy.object_src      :none
    policy.script_src      :self
    policy.style_src       :self
    policy.base_uri        :self
    policy.form_action     :self
    policy.frame_ancestors :none
  end

  config.content_security_policy_report_only = Rails.env.development?
end
