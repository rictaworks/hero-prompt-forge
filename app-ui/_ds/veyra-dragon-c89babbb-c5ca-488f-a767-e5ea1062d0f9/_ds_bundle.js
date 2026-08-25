/* @ds-bundle: {"format":4,"namespace":"VeyraDragon_c89bab","components":[{"name":"Eyebrow","sourcePath":"components/brand/Eyebrow.jsx"},{"name":"Logo","sourcePath":"components/brand/Logo.jsx"},{"name":"SectionHeading","sourcePath":"components/brand/SectionHeading.jsx"},{"name":"VerticalBadge","sourcePath":"components/brand/VerticalBadge.jsx"},{"name":"FaqItem","sourcePath":"components/content/FaqItem.jsx"},{"name":"ProcessStep","sourcePath":"components/content/ProcessStep.jsx"},{"name":"StatItem","sourcePath":"components/content/StatItem.jsx"},{"name":"StrengthCard","sourcePath":"components/content/StrengthCard.jsx"},{"name":"Button","sourcePath":"components/core/Button.jsx"},{"name":"Icon","sourcePath":"components/core/Icon.jsx"},{"name":"Field","sourcePath":"components/forms/Field.jsx"},{"name":"NavBar","sourcePath":"components/navigation/NavBar.jsx"},{"name":"SiteFooter","sourcePath":"components/navigation/SiteFooter.jsx"}],"sourceHashes":{"components/brand/Eyebrow.jsx":"93a9f8b93015","components/brand/Logo.jsx":"4f8629b1e15e","components/brand/SectionHeading.jsx":"dd99468b1f04","components/brand/VerticalBadge.jsx":"e99f706770e5","components/content/FaqItem.jsx":"eb6bed554b8c","components/content/ProcessStep.jsx":"609614db5ef7","components/content/StatItem.jsx":"946b99b13dc1","components/content/StrengthCard.jsx":"62cd56999645","components/core/Button.jsx":"a05df1d40b75","components/core/Icon.jsx":"32bb48ed34ff","components/forms/Field.jsx":"cbc501748097","components/navigation/NavBar.jsx":"051bcb0b4ee6","components/navigation/SiteFooter.jsx":"e7028bcdd1a7","ui_kits/marketing-site/Sections.jsx":"f3ca6a98e77a"},"inlinedExternals":[],"unexposedExports":[]} */

(() => {

const __ds_ns = (window.VeyraDragon_c89bab = window.VeyraDragon_c89bab || {});

const __ds_scope = {};

(__ds_ns.__errors = __ds_ns.__errors || []);

// components/brand/Eyebrow.jsx
try { (() => {
function Eyebrow({
  children,
  align = 'left',
  style
}) {
  return /*#__PURE__*/React.createElement("p", {
    style: {
      fontFamily: 'var(--font-display)',
      fontSize: 'var(--fs-2xs)',
      fontWeight: 700,
      letterSpacing: 'var(--ls-eyebrow)',
      color: 'var(--red)',
      textTransform: 'uppercase',
      marginBottom: '14px',
      textAlign: align,
      ...style
    }
  }, children);
}
Object.assign(__ds_scope, { Eyebrow });
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/brand/Eyebrow.jsx", error: String((e && e.message) || e) }); }

// components/brand/Logo.jsx
try { (() => {
function Logo({
  href = '#',
  size = 'default',
  showWordmark = true,
  style
}) {
  const disc = size === 'sm' ? 28 : 36;
  const [hover, setHover] = React.useState(false);
  return /*#__PURE__*/React.createElement("a", {
    href: href,
    onMouseEnter: () => setHover(true),
    onMouseLeave: () => setHover(false),
    style: {
      display: 'inline-flex',
      alignItems: 'center',
      gap: '10px',
      fontFamily: 'var(--font-display)',
      fontWeight: 800,
      fontSize: size === 'sm' ? '1rem' : 'var(--fs-xl)',
      color: hover ? 'var(--gold-light)' : 'var(--gold)',
      textDecoration: 'none',
      transition: 'color var(--dur-fast)',
      ...style
    }
  }, /*#__PURE__*/React.createElement("span", {
    style: {
      width: disc,
      height: disc,
      background: 'var(--brand-orb)',
      borderRadius: 'var(--radius-full)',
      display: 'flex',
      alignItems: 'center',
      justifyContent: 'center',
      fontSize: size === 'sm' ? '.85rem' : '1rem',
      color: '#fff',
      flex: '0 0 auto'
    }
  }, /*#__PURE__*/React.createElement("i", {
    className: "fa-solid fa-dragon",
    "aria-hidden": "true"
  })), showWordmark ? /*#__PURE__*/React.createElement("span", null, "Veyra Dragon") : null);
}
Object.assign(__ds_scope, { Logo });
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/brand/Logo.jsx", error: String((e && e.message) || e) }); }

// components/brand/SectionHeading.jsx
try { (() => {
const SIZES = {
  default: 'var(--fs-title)',
  sm: 'var(--fs-title-sm)',
  contact: 'clamp(1.8rem, 3vw, 2.4rem)',
  band: 'var(--fs-title-band)'
};
function SectionHeading({
  eyebrow,
  title,
  size = 'default',
  divider = true,
  align = 'left',
  children,
  style
}) {
  return /*#__PURE__*/React.createElement("div", {
    style: {
      textAlign: align,
      ...style
    }
  }, eyebrow ? /*#__PURE__*/React.createElement(__ds_scope.Eyebrow, {
    align: align
  }, eyebrow) : null, /*#__PURE__*/React.createElement("h2", {
    style: {
      fontFamily: 'var(--font-display)',
      fontSize: SIZES[size] || SIZES.default,
      fontWeight: 800,
      color: 'var(--text-heading)',
      lineHeight: 'var(--lh-title)',
      marginBottom: '20px'
    }
  }, title), divider ? /*#__PURE__*/React.createElement("div", {
    style: {
      width: 'var(--divider-w)',
      height: 'var(--divider-h)',
      background: 'var(--red)',
      margin: align === 'center' ? '20px auto' : '20px 0'
    }
  }) : null, children ? /*#__PURE__*/React.createElement("p", {
    style: {
      fontSize: 'var(--fs-base)',
      color: 'var(--text-muted)',
      lineHeight: 'var(--lh-loose)'
    }
  }, children) : null);
}
Object.assign(__ds_scope, { SectionHeading });
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/brand/SectionHeading.jsx", error: String((e && e.message) || e) }); }

// components/brand/VerticalBadge.jsx
try { (() => {
function VerticalBadge({
  children = 'SINCE 2020',
  style
}) {
  return /*#__PURE__*/React.createElement("div", {
    style: {
      display: 'flex',
      flexDirection: 'column',
      alignItems: 'flex-end',
      gap: '4px',
      ...style
    }
  }, /*#__PURE__*/React.createElement("span", {
    style: {
      display: 'block',
      width: '2px',
      height: '30px',
      background: 'var(--red)',
      marginLeft: 'auto'
    }
  }), /*#__PURE__*/React.createElement("span", {
    style: {
      fontFamily: 'var(--font-display)',
      fontSize: 'var(--fs-3xs)',
      letterSpacing: 'var(--ls-badge)',
      color: 'var(--red)',
      writingMode: 'vertical-rl'
    }
  }, children));
}
Object.assign(__ds_scope, { VerticalBadge });
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/brand/VerticalBadge.jsx", error: String((e && e.message) || e) }); }

// components/content/FaqItem.jsx
try { (() => {
function FaqItem({
  question,
  children,
  open,
  defaultOpen = false,
  onToggle,
  style
}) {
  const [inner, setInner] = React.useState(defaultOpen);
  const [hover, setHover] = React.useState(false);
  const isOpen = open === undefined ? inner : open;
  const toggle = () => {
    if (open === undefined) setInner(!isOpen);
    if (onToggle) onToggle(!isOpen);
  };
  return /*#__PURE__*/React.createElement("div", {
    style: {
      borderBottom: 'var(--border-hairline)',
      ...style
    }
  }, /*#__PURE__*/React.createElement("div", {
    role: "button",
    tabIndex: 0,
    onClick: toggle,
    onKeyDown: e => {
      if (e.key === 'Enter' || e.key === ' ') {
        e.preventDefault();
        toggle();
      }
    },
    onMouseEnter: () => setHover(true),
    onMouseLeave: () => setHover(false),
    style: {
      display: 'flex',
      alignItems: 'center',
      justifyContent: 'space-between',
      padding: '22px 0',
      cursor: 'pointer',
      fontSize: 'var(--fs-md)',
      color: hover ? '#fff' : 'var(--grey-ccc)',
      fontWeight: 500,
      transition: 'var(--transition-color)',
      userSelect: 'none'
    }
  }, /*#__PURE__*/React.createElement("span", null, question), /*#__PURE__*/React.createElement("i", {
    className: "fa-solid fa-chevron-down",
    "aria-hidden": "true",
    style: {
      color: 'var(--red)',
      fontSize: 'var(--fs-sm)',
      transition: 'transform var(--dur-med)',
      transform: isOpen ? 'rotate(180deg)' : 'none'
    }
  })), /*#__PURE__*/React.createElement("div", {
    style: {
      maxHeight: isOpen ? '200px' : 0,
      overflow: 'hidden',
      paddingBottom: isOpen ? '18px' : 0,
      transition: 'max-height var(--dur-slow) var(--ease), padding var(--dur-med)'
    }
  }, /*#__PURE__*/React.createElement("p", {
    style: {
      fontSize: 'var(--fs-sm-4)',
      color: 'var(--text-muted)',
      lineHeight: 'var(--lh-relaxed)'
    }
  }, children)));
}
Object.assign(__ds_scope, { FaqItem });
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/content/FaqItem.jsx", error: String((e && e.message) || e) }); }

// components/content/ProcessStep.jsx
try { (() => {
function ProcessStep({
  step,
  icon,
  title,
  children,
  style
}) {
  return /*#__PURE__*/React.createElement("div", {
    style: {
      display: 'grid',
      gridTemplateColumns: '90px 64px 1fr',
      alignItems: 'stretch',
      padding: '24px 0',
      borderBottom: 'var(--border-hairline)',
      position: 'relative',
      ...style
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      fontFamily: 'var(--font-display)',
      fontSize: 'var(--fs-2xs)',
      fontWeight: 700,
      letterSpacing: 'var(--ls-step)',
      color: 'var(--red)',
      paddingTop: '4px'
    }
  }, "Step ", /*#__PURE__*/React.createElement("span", {
    style: {
      display: 'block',
      fontSize: 'var(--fs-2xl)',
      fontWeight: 900,
      color: 'var(--text-heading)',
      letterSpacing: 0
    }
  }, step)), /*#__PURE__*/React.createElement("div", {
    style: {
      position: 'relative',
      display: 'flex',
      flexDirection: 'column',
      alignItems: 'center'
    }
  }, /*#__PURE__*/React.createElement("span", {
    style: {
      position: 'absolute',
      top: 0,
      bottom: 0,
      left: '50%',
      width: '1px',
      background: 'var(--border)',
      transform: 'translateX(-50%)'
    }
  }), /*#__PURE__*/React.createElement("div", {
    style: {
      width: 'var(--step-disc)',
      height: 'var(--step-disc)',
      background: 'var(--red)',
      borderRadius: 'var(--radius-full)',
      display: 'flex',
      alignItems: 'center',
      justifyContent: 'center',
      fontSize: '1rem',
      color: '#fff',
      position: 'relative',
      zIndex: 1
    }
  }, /*#__PURE__*/React.createElement("i", {
    className: 'fa-solid fa-' + icon,
    "aria-hidden": "true"
  }))), /*#__PURE__*/React.createElement("div", {
    style: {
      paddingLeft: '24px'
    }
  }, /*#__PURE__*/React.createElement("h3", {
    style: {
      fontFamily: 'var(--font-display)',
      fontSize: 'var(--fs-lg)',
      fontWeight: 700,
      color: 'var(--text-heading)',
      marginBottom: '6px'
    }
  }, title), /*#__PURE__*/React.createElement("p", {
    style: {
      fontSize: 'var(--fs-sm-3)',
      color: 'var(--grey-777)',
      lineHeight: 'var(--lh-relaxed)'
    }
  }, children)));
}
Object.assign(__ds_scope, { ProcessStep });
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/content/ProcessStep.jsx", error: String((e && e.message) || e) }); }

// components/content/StatItem.jsx
try { (() => {
function StatItem({
  icon,
  iconVariant = 'solid',
  value,
  label,
  last = false,
  style
}) {
  return /*#__PURE__*/React.createElement("div", {
    style: {
      padding: '50px 40px',
      borderRight: last ? 'none' : 'var(--border-hairline)',
      display: 'flex',
      alignItems: 'center',
      gap: '24px',
      position: 'relative',
      textAlign: 'left',
      ...style
    }
  }, icon ? /*#__PURE__*/React.createElement("div", {
    style: {
      fontSize: '2rem',
      color: 'var(--border)'
    }
  }, /*#__PURE__*/React.createElement("i", {
    className: 'fa-' + iconVariant + ' fa-' + icon,
    "aria-hidden": "true"
  })) : null, /*#__PURE__*/React.createElement("div", null, /*#__PURE__*/React.createElement("div", {
    style: {
      fontFamily: 'var(--font-display)',
      fontSize: 'var(--fs-stat)',
      fontWeight: 900,
      color: 'var(--text-heading)',
      lineHeight: 'var(--lh-tight)'
    }
  }, value), /*#__PURE__*/React.createElement("div", {
    style: {
      fontSize: 'var(--fs-sm)',
      color: 'var(--text-muted)',
      marginTop: '4px'
    }
  }, label)), /*#__PURE__*/React.createElement("span", {
    style: {
      position: 'absolute',
      bottom: 0,
      left: '40px',
      width: 'var(--rule-accent-w)',
      height: 'var(--rule-accent-h)',
      background: 'var(--red)'
    }
  }));
}
Object.assign(__ds_scope, { StatItem });
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/content/StatItem.jsx", error: String((e && e.message) || e) }); }

// components/content/StrengthCard.jsx
try { (() => {
function StrengthCard({
  icon,
  title,
  children,
  style
}) {
  const [hover, setHover] = React.useState(false);
  return /*#__PURE__*/React.createElement("div", {
    onMouseEnter: () => setHover(true),
    onMouseLeave: () => setHover(false),
    style: {
      background: 'var(--card-bg)',
      border: '1px solid ' + (hover ? 'var(--red)' : 'var(--border)'),
      padding: '36px 28px',
      transform: hover ? 'translateY(-4px)' : 'none',
      transition: 'var(--transition-card)',
      ...style
    }
  }, icon ? /*#__PURE__*/React.createElement("div", {
    style: {
      width: 'var(--icon-disc)',
      height: 'var(--icon-disc)',
      background: 'var(--tint-red-15)',
      borderRadius: 'var(--radius-full)',
      display: 'flex',
      alignItems: 'center',
      justifyContent: 'center',
      fontSize: '1.3rem',
      color: 'var(--red)',
      marginBottom: '20px'
    }
  }, /*#__PURE__*/React.createElement("i", {
    className: 'fa-solid fa-' + icon,
    "aria-hidden": "true"
  })) : null, /*#__PURE__*/React.createElement("h3", {
    style: {
      fontFamily: 'var(--font-display)',
      fontSize: 'var(--fs-lg)',
      fontWeight: 700,
      color: 'var(--text-heading)',
      marginBottom: '12px'
    }
  }, title), /*#__PURE__*/React.createElement("p", {
    style: {
      fontSize: 'var(--fs-sm-2)',
      color: 'var(--grey-777)',
      lineHeight: 'var(--lh-relaxed)'
    }
  }, children));
}
Object.assign(__ds_scope, { StrengthCard });
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/content/StrengthCard.jsx", error: String((e && e.message) || e) }); }

// components/core/Button.jsx
try { (() => {
const VARIANTS = {
  outline: {
    base: {
      padding: '14px 28px',
      border: 'var(--border-cta)',
      background: 'transparent',
      color: 'var(--gold)',
      fontSize: 'var(--fs-base)',
      fontWeight: 600,
      borderRadius: 'var(--radius-none)',
      transition: 'background var(--dur-fast), color var(--dur-fast)'
    },
    hover: {
      background: 'var(--gold)',
      color: '#000'
    }
  },
  solid: {
    base: {
      padding: '8px 22px',
      border: 'none',
      background: 'var(--red)',
      color: '#fff',
      fontSize: 'var(--fs-base)',
      fontWeight: 600,
      borderRadius: 'var(--radius-button)',
      transition: 'background var(--dur-fast)'
    },
    hover: {
      background: 'var(--red-bright)'
    }
  },
  submit: {
    base: {
      width: '100%',
      padding: '16px',
      border: 'none',
      background: 'var(--red)',
      color: '#fff',
      fontSize: 'var(--fs-base-2)',
      fontWeight: 700,
      borderRadius: 'var(--radius-none)',
      transition: 'background var(--dur-fast)'
    },
    hover: {
      background: 'var(--red-bright)'
    }
  }
};
function Button({
  variant = 'outline',
  href,
  icon,
  iconPosition = 'end',
  fullWidth = false,
  disabled = false,
  onClick,
  children,
  style,
  ...rest
}) {
  const [hover, setHover] = React.useState(false);
  const v = VARIANTS[variant] || VARIANTS.outline;
  const css = Object.assign({
    display: 'inline-flex',
    alignItems: 'center',
    justifyContent: 'center',
    gap: '10px',
    fontFamily: 'var(--font-display)',
    letterSpacing: 'var(--ls-button)',
    lineHeight: 1.2,
    textDecoration: 'none',
    cursor: disabled ? 'not-allowed' : 'pointer'
  }, v.base, fullWidth ? {
    width: '100%'
  } : null, hover && !disabled ? v.hover : null, disabled ? {
    opacity: 0.4
  } : null, style);
  const glyph = icon ? React.createElement('i', {
    className: 'fa-solid fa-' + icon,
    'aria-hidden': 'true'
  }) : null;
  const content = [iconPosition === 'start' ? glyph : null, React.createElement('span', {
    key: 'l'
  }, children), iconPosition === 'end' ? glyph : null];
  const props = {
    style: css,
    onMouseEnter: () => setHover(true),
    onMouseLeave: () => setHover(false),
    onClick: disabled ? undefined : onClick,
    ...rest
  };
  return href && !disabled ? React.createElement('a', {
    href,
    ...props
  }, content) : React.createElement('button', {
    type: variant === 'submit' ? 'submit' : 'button',
    disabled,
    ...props
  }, content);
}
Object.assign(__ds_scope, { Button });
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/core/Button.jsx", error: String((e && e.message) || e) }); }

// components/core/Icon.jsx
try { (() => {
function Icon({
  name,
  variant = 'solid',
  size,
  color,
  style,
  ...rest
}) {
  return React.createElement('i', {
    className: 'fa-' + variant + ' fa-' + name,
    'aria-hidden': 'true',
    style: Object.assign({
      fontSize: size,
      color,
      lineHeight: 1
    }, style),
    ...rest
  });
}
Object.assign(__ds_scope, { Icon });
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/core/Icon.jsx", error: String((e && e.message) || e) }); }

// components/forms/Field.jsx
try { (() => {
function _extends() { return _extends = Object.assign ? Object.assign.bind() : function (n) { for (var e = 1; e < arguments.length; e++) { var t = arguments[e]; for (var r in t) ({}).hasOwnProperty.call(t, r) && (n[r] = t[r]); } return n; }, _extends.apply(null, arguments); }
function Field({
  multiline = false,
  placeholder,
  value,
  defaultValue,
  onChange,
  type = 'text',
  rows,
  style,
  ...rest
}) {
  const [focus, setFocus] = React.useState(false);
  const css = {
    width: '100%',
    background: 'var(--field-bg)',
    border: '1px solid ' + (focus ? 'var(--red)' : 'var(--field-border)'),
    color: '#fff',
    padding: '14px 18px',
    fontFamily: 'var(--font-body)',
    fontSize: 'var(--fs-base)',
    outline: 'none',
    transition: 'border-color var(--dur-fast)',
    resize: 'none',
    borderRadius: 'var(--radius-field)',
    ...(multiline ? {
      height: 'var(--textarea-h)'
    } : null),
    ...style
  };
  const shared = {
    placeholder,
    value,
    defaultValue,
    onChange,
    style: css,
    onFocus: () => setFocus(true),
    onBlur: () => setFocus(false),
    ...rest
  };
  return multiline ? /*#__PURE__*/React.createElement("textarea", _extends({
    rows: rows
  }, shared)) : /*#__PURE__*/React.createElement("input", _extends({
    type: type
  }, shared));
}
Object.assign(__ds_scope, { Field });
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/forms/Field.jsx", error: String((e && e.message) || e) }); }

// components/navigation/NavBar.jsx
try { (() => {
function NavLink({
  href,
  children,
  onClick
}) {
  const [hover, setHover] = React.useState(false);
  return /*#__PURE__*/React.createElement("li", null, /*#__PURE__*/React.createElement("a", {
    href: href,
    onClick: onClick,
    onMouseEnter: () => setHover(true),
    onMouseLeave: () => setHover(false),
    style: {
      color: hover ? 'var(--gold)' : 'var(--text)',
      textDecoration: 'none',
      fontSize: 'var(--fs-base)',
      letterSpacing: 'var(--ls-nav)',
      transition: 'var(--transition-color)'
    }
  }, children));
}
function NavBar({
  links = [],
  cta,
  ctaHref = '#contact',
  position = 'fixed',
  onNavigate,
  style
}) {
  const [open, setOpen] = React.useState(false);
  return /*#__PURE__*/React.createElement("nav", {
    style: {
      position,
      top: 0,
      left: 0,
      right: 0,
      zIndex: 100,
      display: 'flex',
      alignItems: 'center',
      justifyContent: 'space-between',
      padding: '0 5%',
      height: 'var(--nav-height)',
      background: 'var(--scrim-92)',
      backdropFilter: 'var(--blur-nav)',
      WebkitBackdropFilter: 'var(--blur-nav)',
      borderBottom: 'var(--border-hairline)',
      ...style
    }
  }, /*#__PURE__*/React.createElement(__ds_scope.Logo, {
    href: "#"
  }), /*#__PURE__*/React.createElement("ul", {
    style: {
      display: 'flex',
      alignItems: 'center',
      gap: '36px',
      listStyle: 'none',
      margin: 0,
      padding: 0
    }
  }, links.map(l => /*#__PURE__*/React.createElement(NavLink, {
    key: l.href,
    href: l.href,
    onClick: onNavigate ? e => onNavigate(l, e) : undefined
  }, l.label)), cta ? /*#__PURE__*/React.createElement("li", null, /*#__PURE__*/React.createElement(__ds_scope.Button, {
    variant: "solid",
    href: ctaHref,
    onClick: onNavigate ? e => onNavigate({
      href: ctaHref,
      label: cta
    }, e) : undefined
  }, cta)) : null), /*#__PURE__*/React.createElement("div", {
    onClick: () => setOpen(!open),
    "aria-label": "Menu",
    style: {
      display: 'none',
      flexDirection: 'column',
      gap: '5px',
      cursor: 'pointer'
    }
  }, /*#__PURE__*/React.createElement("span", {
    style: {
      display: 'block',
      width: '24px',
      height: '2px',
      background: 'var(--text)'
    }
  }), /*#__PURE__*/React.createElement("span", {
    style: {
      display: 'block',
      width: '24px',
      height: '2px',
      background: 'var(--text)'
    }
  }), /*#__PURE__*/React.createElement("span", {
    style: {
      display: 'block',
      width: '24px',
      height: '2px',
      background: 'var(--text)'
    }
  })));
}
Object.assign(__ds_scope, { NavBar });
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/navigation/NavBar.jsx", error: String((e && e.message) || e) }); }

// components/navigation/SiteFooter.jsx
try { (() => {
function _extends() { return _extends = Object.assign ? Object.assign.bind() : function (n) { for (var e = 1; e < arguments.length; e++) { var t = arguments[e]; for (var r in t) ({}).hasOwnProperty.call(t, r) && (n[r] = t[r]); } return n; }, _extends.apply(null, arguments); }
function SocialTile({
  href = '#',
  icon,
  label
}) {
  const [hover, setHover] = React.useState(false);
  return /*#__PURE__*/React.createElement("a", {
    href: href,
    "aria-label": label,
    onMouseEnter: () => setHover(true),
    onMouseLeave: () => setHover(false),
    style: {
      width: 'var(--social-tile)',
      height: 'var(--social-tile)',
      background: 'var(--dark3)',
      border: '1px solid ' + (hover ? 'var(--gold)' : 'var(--border)'),
      borderRadius: 'var(--radius-media)',
      display: 'flex',
      alignItems: 'center',
      justifyContent: 'center',
      color: hover ? 'var(--gold)' : 'var(--text-muted)',
      fontSize: 'var(--fs-base-2)',
      textDecoration: 'none',
      transition: 'border-color var(--dur-fast), color var(--dur-fast)'
    }
  }, /*#__PURE__*/React.createElement("i", {
    className: 'fa-brands fa-' + icon,
    "aria-hidden": "true"
  }));
}
function FooterLink({
  href,
  children
}) {
  const [hover, setHover] = React.useState(false);
  return /*#__PURE__*/React.createElement("li", null, /*#__PURE__*/React.createElement("a", {
    href: href,
    onMouseEnter: () => setHover(true),
    onMouseLeave: () => setHover(false),
    style: {
      fontSize: 'var(--fs-sm-3)',
      color: hover ? '#fff' : 'var(--grey-777)',
      textDecoration: 'none',
      transition: 'var(--transition-color)'
    }
  }, children));
}
function SiteFooter({
  blurb,
  socials = [],
  columns = [],
  bottom,
  style
}) {
  return /*#__PURE__*/React.createElement("footer", {
    style: {
      background: 'var(--dark2)',
      borderTop: 'var(--border-hairline)',
      ...style
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      display: 'grid',
      gridTemplateColumns: 'var(--col-footer-brand) 1fr 1fr',
      gap: '60px',
      padding: '64px 6% 48px'
    }
  }, /*#__PURE__*/React.createElement("div", null, /*#__PURE__*/React.createElement(__ds_scope.Logo, {
    href: "#",
    style: {
      marginBottom: '16px'
    }
  }), /*#__PURE__*/React.createElement("p", {
    style: {
      fontSize: 'var(--fs-sm)',
      color: 'var(--grey-666)',
      lineHeight: 'var(--lh-relaxed)'
    }
  }, blurb), socials.length ? /*#__PURE__*/React.createElement("div", {
    style: {
      display: 'flex',
      gap: '14px',
      marginTop: '20px'
    }
  }, socials.map(s => /*#__PURE__*/React.createElement(SocialTile, _extends({
    key: s.icon
  }, s)))) : null), columns.map(col => /*#__PURE__*/React.createElement("div", {
    key: col.title
  }, /*#__PURE__*/React.createElement("h4", {
    style: {
      fontFamily: 'var(--font-display)',
      fontSize: 'var(--fs-xs)',
      fontWeight: 700,
      letterSpacing: 'var(--ls-footer-head)',
      textTransform: 'uppercase',
      color: 'var(--gold)',
      marginBottom: '18px'
    }
  }, col.title), /*#__PURE__*/React.createElement("ul", {
    style: {
      listStyle: 'none',
      display: 'flex',
      flexDirection: 'column',
      gap: '10px',
      margin: 0,
      padding: 0
    }
  }, col.links.map(l => /*#__PURE__*/React.createElement(FooterLink, {
    key: l.label,
    href: l.href
  }, l.label)))))), /*#__PURE__*/React.createElement("div", {
    style: {
      borderTop: 'var(--border-hairline)',
      padding: '20px 6%',
      textAlign: 'center',
      fontSize: 'var(--fs-xs)',
      color: 'var(--grey-555)'
    }
  }, bottom));
}
Object.assign(__ds_scope, { SiteFooter });
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/navigation/SiteFooter.jsx", error: String((e && e.message) || e) }); }

// ui_kits/marketing-site/Sections.jsx
try { (() => {
const {
  Button,
  VerticalBadge,
  SectionHeading,
  Eyebrow,
  StrengthCard,
  StatItem,
  ProcessStep,
  FaqItem,
  Field
} = window.VeyraDragon_c89bab;
const SECTION = {
  padding: '80px 6%'
};
function Hero() {
  return /*#__PURE__*/React.createElement("section", {
    id: "hero",
    style: {
      position: 'relative',
      minHeight: '100vh',
      display: 'flex',
      alignItems: 'center',
      padding: '0 6%',
      overflow: 'hidden'
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      position: 'absolute',
      inset: 0,
      background: "url('../../assets/hero_background.webp') center/cover no-repeat",
      filter: 'var(--filter-hero)'
    }
  }), /*#__PURE__*/React.createElement("div", {
    style: {
      position: 'absolute',
      inset: 0,
      background: 'var(--fade-hero)'
    }
  }), /*#__PURE__*/React.createElement("div", {
    style: {
      position: 'relative',
      zIndex: 2,
      maxWidth: 'var(--hero-max-w)',
      paddingTop: '80px'
    }
  }, /*#__PURE__*/React.createElement("h1", {
    style: {
      fontFamily: 'var(--font-display)',
      fontSize: 'var(--fs-hero)',
      fontWeight: 900,
      lineHeight: 'var(--lh-hero)',
      color: '#fff',
      marginBottom: '20px'
    }
  }, "Elevate Your", /*#__PURE__*/React.createElement("br", null), "Vision to", /*#__PURE__*/React.createElement("br", null), "the ", /*#__PURE__*/React.createElement("span", {
    style: {
      color: 'var(--red-bright)'
    }
  }, "Skies.")), /*#__PURE__*/React.createElement("p", {
    style: {
      fontSize: 'var(--fs-md-2)',
      color: 'var(--grey-bbb)',
      marginBottom: '36px'
    }
  }, "\u30D2\u30FC\u30ED\u30FC\u30BB\u30AF\u30B7\u30E7\u30F3\u306E\u30B5\u30D6\u30B3\u30D4\u30FC\u3002\u30D5\u30A1\u30FC\u30B9\u30C8\u30D3\u30E5\u30FC\u3067\u8A2A\u554F\u8005\u306E\u5FC3\u3092\u63B4\u3080\u3001\u30D6\u30E9\u30F3\u30C9\u306E\u6838\u5FC3\u3092\u4F1D\u3048\u308B\u4E00\u6587\u3092\u914D\u7F6E\u3059\u308B\u30A8\u30EA\u30A2\u3067\u3059\u3002"), /*#__PURE__*/React.createElement(Button, {
    variant: "outline",
    href: "#strengths",
    icon: "chevron-right"
  }, "\u30D7\u30ED\u30B8\u30A7\u30AF\u30C8\u306E\u8A73\u7D30\u3092\u898B\u308B")), /*#__PURE__*/React.createElement("div", {
    style: {
      position: 'absolute',
      bottom: '32px',
      left: '50%',
      transform: 'translateX(-50%)',
      zIndex: 2
    }
  }, /*#__PURE__*/React.createElement("div", {
    className: "vd-scroll",
    style: {
      width: '1px',
      height: '40px',
      background: 'linear-gradient(to bottom, transparent, var(--gold))'
    }
  })));
}
function Essence() {
  return /*#__PURE__*/React.createElement("section", {
    id: "essence",
    style: {
      ...SECTION,
      background: 'var(--dark2)',
      display: 'grid',
      gridTemplateColumns: '1fr 1fr',
      gap: '60px',
      alignItems: 'center'
    }
  }, /*#__PURE__*/React.createElement("div", null, /*#__PURE__*/React.createElement(SectionHeading, {
    eyebrow: "OUR ESSENCE",
    title: /*#__PURE__*/React.createElement(React.Fragment, null, "\u529B\u5F37\u304F\u3001\u3057\u306A\u3084\u304B\u306B\u3001", /*#__PURE__*/React.createElement("br", null), "\u672A\u6765\u3092\u5207\u308A\u62D3\u304F\u3002")
  }, "\u30D6\u30E9\u30F3\u30C9\u306E\u30B3\u30A2\u30D0\u30EA\u30E5\u30FC\u3068\u5B58\u5728\u610F\u7FA9\u3092\u4F1D\u3048\u308B\u30E1\u30A4\u30F3\u30C6\u30AD\u30B9\u30C8\u30D6\u30ED\u30C3\u30AF\u3002\u4F01\u696D\u306E\u30D3\u30B8\u30E7\u30F3\u3084\u54F2\u5B66\u3001\u9867\u5BA2\u3078\u306E\u7D04\u675F\u3092\u4E01\u5BE7\u306B\u8AAC\u660E\u3059\u308B\u6587\u7AE0\u3092\u914D\u7F6E\u3057\u307E\u3059\u3002\u5DE6\u30AB\u30E9\u30E0\u306B\u30C6\u30AD\u30B9\u30C8\u3001\u53F3\u30AB\u30E9\u30E0\u306B\u30D3\u30B8\u30E5\u30A2\u30EB\u3092\u914D\u7F6E\u3057\u305F\u4E8C\u6BB5\u7D44\u30EC\u30A4\u30A2\u30A6\u30C8\u3067\u3001\u8AAD\u307F\u3084\u3059\u3055\u3068\u8996\u899A\u7684\u30A4\u30F3\u30D1\u30AF\u30C8\u3092\u4E21\u7ACB\u3057\u3066\u3044\u307E\u3059\u3002\u6BB5\u843D\u3054\u3068\u306B\u884C\u9593\u3092\u5E83\u304F\u3068\u308B\u3053\u3068\u3067\u3001\u9AD8\u7D1A\u611F\u306E\u3042\u308B\u8AAD\u66F8\u4F53\u9A13\u3092\u63D0\u4F9B\u3057\u307E\u3059\u3002")), /*#__PURE__*/React.createElement("div", {
    style: {
      position: 'relative',
      height: 'var(--essence-image-h)',
      borderRadius: 'var(--radius-media)',
      overflow: 'hidden'
    }
  }, /*#__PURE__*/React.createElement("img", {
    src: "../../assets/essence_image.webp",
    alt: "\u30D6\u30E9\u30F3\u30C9\u30A4\u30E1\u30FC\u30B8",
    style: {
      width: '100%',
      height: '100%',
      objectFit: 'cover',
      filter: 'var(--filter-photo)'
    }
  }), /*#__PURE__*/React.createElement("div", {
    style: {
      position: 'absolute',
      inset: 0,
      background: 'var(--fade-vignette)'
    }
  }), /*#__PURE__*/React.createElement(VerticalBadge, {
    style: {
      position: 'absolute',
      bottom: '20px',
      right: '20px'
    }
  }, "SINCE 2020")));
}
function Strengths() {
  const cards = [{
    icon: 'shield-halved',
    title: 'Security & Trust',
    body: 'セキュリティと信頼性の強みを説明するカード。具体的な施策・指標・実績を記載し、顧客の安心感を醸成します。'
  }, {
    icon: 'bolt',
    title: 'High Performance',
    body: 'パフォーマンスの優位性を訴求するカード。速度・安定性・スケーラビリティなど定量的な強みを伝えます。'
  }, {
    icon: 'chart-line',
    title: 'Strategic Growth',
    body: '戦略的成長支援を示すカード。データドリブンなアプローチで競合優位性を生み出すプロセスを説明します。'
  }];
  return /*#__PURE__*/React.createElement("section", {
    id: "strengths",
    style: {
      ...SECTION,
      background: 'var(--dark)',
      display: 'grid',
      gridTemplateColumns: 'var(--col-sidebar) 1fr',
      gap: '60px',
      alignItems: 'start'
    }
  }, /*#__PURE__*/React.createElement(SectionHeading, {
    eyebrow: "WHAT WE DO",
    title: /*#__PURE__*/React.createElement(React.Fragment, null, "Our Scales", /*#__PURE__*/React.createElement("br", null), "(Strengths)"),
    size: "sm"
  }, "\u30B5\u30FC\u30D3\u30B9\u306E\u5F37\u307F\u3092\u793A\u3059\u5DE6\u30AB\u30E9\u30E0\u306E\u30CA\u30D3\u30B2\u30FC\u30B7\u30E7\u30F3\u30C6\u30AD\u30B9\u30C8\u3002\u53F3\u5074\u306B\u5C55\u958B\u3055\u308C\u308B3\u679A\u306E\u30AB\u30FC\u30C9\u306E\u6982\u8981\u3092\u4F1D\u3048\u3001\u30BB\u30AF\u30B7\u30E7\u30F3\u5168\u4F53\u306E\u6587\u8108\u3092\u8A2D\u5B9A\u3059\u308B\u5F79\u5272\u3092\u62C5\u3044\u307E\u3059\u3002"), /*#__PURE__*/React.createElement("div", {
    style: {
      display: 'grid',
      gridTemplateColumns: 'repeat(3, 1fr)',
      gap: '2px'
    }
  }, cards.map(c => /*#__PURE__*/React.createElement(StrengthCard, {
    key: c.title,
    icon: c.icon,
    title: c.title
  }, c.body))));
}
function Numbers() {
  return /*#__PURE__*/React.createElement("section", {
    id: "numbers",
    style: {
      ...SECTION,
      position: 'relative',
      textAlign: 'center',
      background: "url('../../assets/numbers_background.webp') center/cover fixed no-repeat"
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      position: 'absolute',
      inset: 0,
      background: 'var(--scrim-82)'
    }
  }), /*#__PURE__*/React.createElement("div", {
    style: {
      position: 'relative',
      zIndex: 2
    }
  }, /*#__PURE__*/React.createElement(Eyebrow, {
    align: "center"
  }, "PROVEN RESULTS"), /*#__PURE__*/React.createElement("h2", {
    style: {
      fontFamily: 'var(--font-display)',
      fontSize: 'var(--fs-title-band)',
      fontWeight: 800,
      color: '#fff',
      marginBottom: '60px'
    }
  }, "Performance in Numbers"), /*#__PURE__*/React.createElement("div", {
    style: {
      display: 'grid',
      gridTemplateColumns: 'repeat(3, 1fr)',
      border: 'var(--border-hairline)'
    }
  }, /*#__PURE__*/React.createElement(StatItem, {
    icon: "circle-check",
    iconVariant: "regular",
    value: "98%",
    label: "\u9867\u5BA2\u6E80\u8DB3\u5EA6 \u2014 \u9AD8\u3044\u9867\u5BA2\u6E80\u8DB3\u5EA6\u3092\u793A\u3059\u4E3B\u8981KPI\u6307\u6A19"
  }), /*#__PURE__*/React.createElement(StatItem, {
    icon: "crosshairs",
    value: "500+",
    label: "\u30D7\u30ED\u30B8\u30A7\u30AF\u30C8\u5B8C\u9042\u6570 \u2014 \u7D2F\u8A08\u5B9F\u7E3E\u4EF6\u6570\u3092\u793A\u3059\u6570\u5024"
  }), /*#__PURE__*/React.createElement(StatItem, {
    icon: "arrow-trend-down",
    value: "35%",
    label: "\u904B\u7528\u30B3\u30B9\u30C8\u524A\u6E1B \u2014 \u5C0E\u5165\u5F8C\u306E\u5E73\u5747\u30B3\u30B9\u30C8\u524A\u6E1B\u7387",
    last: true
  }))));
}
function Process() {
  const steps = [{
    step: '01',
    icon: 'comments',
    title: 'Consulting',
    body: 'コンサルティングフェーズの説明。現状分析・課題抽出・目標設定を行い、プロジェクトの方向性を明確化するステップの詳細を記載します。'
  }, {
    step: '02',
    icon: 'chess-knight',
    title: 'Strategy',
    body: '戦略立案フェーズの説明。コンサルティングで得た知見をもとに、最適なアクションプランと成功への道筋を設計するステップです。'
  }, {
    step: '03',
    icon: 'code',
    title: 'Implementation',
    body: '実装フェーズの説明。策定した戦略を高品質な技術力で実装し、テストと検証を繰り返しながら確実に形にするステップです。'
  }, {
    step: '04',
    icon: 'handshake',
    title: 'Support',
    body: 'サポートフェーズの説明。導入後も継続的なサポートと改善提案を行い、長期的な成果と顧客満足度の維持を実現するステップです。'
  }];
  return /*#__PURE__*/React.createElement("section", {
    id: "process",
    style: {
      ...SECTION,
      background: 'var(--dark2)',
      display: 'grid',
      gridTemplateColumns: 'var(--col-sidebar) 1fr',
      gap: '80px',
      alignItems: 'start'
    }
  }, /*#__PURE__*/React.createElement(SectionHeading, {
    eyebrow: "OUR PROCESS",
    title: /*#__PURE__*/React.createElement(React.Fragment, null, "Our Journey", /*#__PURE__*/React.createElement("br", null), "Together"),
    size: "sm"
  }, "\u30D7\u30ED\u30BB\u30B9\u30BB\u30AF\u30B7\u30E7\u30F3\u306E\u5DE6\u30AB\u30E9\u30E0\u8AAC\u660E\u6587\u30024\u3064\u306E\u30B9\u30C6\u30C3\u30D7\u3067\u69CB\u6210\u3055\u308C\u308B\u30B5\u30FC\u30D3\u30B9\u63D0\u4F9B\u30D5\u30ED\u30FC\u306E\u5168\u4F53\u50CF\u3092\u7C21\u6F54\u306B\u4F1D\u3048\u3001\u53F3\u5074\u306E\u30BF\u30A4\u30E0\u30E9\u30A4\u30F3\u3078\u306E\u5C0E\u7DDA\u3068\u306A\u308A\u307E\u3059\u3002"), /*#__PURE__*/React.createElement("div", {
    style: {
      display: 'flex',
      flexDirection: 'column'
    }
  }, steps.map(s => /*#__PURE__*/React.createElement(ProcessStep, {
    key: s.step,
    step: s.step,
    icon: s.icon,
    title: s.title
  }, s.body))));
}
function Faq() {
  const [open, setOpen] = React.useState(0);
  const items = [{
    q: 'Q. 導入までの期間はどのくらいですか？',
    a: '導入期間に関するFAQ回答テキスト。プロジェクトの規模・複雑性・要件の程度に応じた目安期間と、スムーズな導入のためのポイントを説明します。'
  }, {
    q: 'Q. サポート体制はどのようになっていますか？',
    a: 'サポート体制に関するFAQ回答。対応時間・チャネル・SLA（サービスレベル合意）など、顧客が安心できる支援体制の詳細を記載します。'
  }, {
    q: 'Q. 費用感を知りたいのですが？',
    a: '費用・料金プランに関するFAQ回答。価格体系の概要、見積もり方法、初期費用と月次費用の考え方などを分かりやすく説明します。'
  }, {
    q: 'Q. セキュリティ対策はどのように行っていますか？',
    a: 'セキュリティ対策に関するFAQ回答。採用している技術基準・認証・定期的な脆弱性診断など、顧客データを保護するための取り組みを説明します。'
  }];
  return /*#__PURE__*/React.createElement("section", {
    id: "faq",
    style: {
      ...SECTION,
      background: 'var(--dark)'
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      display: 'grid',
      gridTemplateColumns: 'var(--col-sidebar) 1fr',
      gap: '80px'
    }
  }, /*#__PURE__*/React.createElement(SectionHeading, {
    eyebrow: "FAQ",
    title: /*#__PURE__*/React.createElement(React.Fragment, null, "\u3088\u304F\u3042\u308B", /*#__PURE__*/React.createElement("br", null), "\u3054\u8CEA\u554F"),
    size: "sm"
  }), /*#__PURE__*/React.createElement("div", {
    style: {
      display: 'flex',
      flexDirection: 'column'
    }
  }, items.map((it, i) => /*#__PURE__*/React.createElement(FaqItem, {
    key: i,
    question: it.q,
    open: open === i,
    onToggle: () => setOpen(open === i ? -1 : i)
  }, it.a)))));
}
function Contact() {
  const [sent, setSent] = React.useState(false);
  return /*#__PURE__*/React.createElement("section", {
    id: "contact",
    style: {
      ...SECTION,
      position: 'relative',
      background: "url('../../assets/contact_background.webp') center/cover no-repeat",
      display: 'grid',
      gridTemplateColumns: '1fr 1fr',
      gap: '80px',
      alignItems: 'center'
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      position: 'absolute',
      inset: 0,
      background: 'var(--scrim-85)'
    }
  }), /*#__PURE__*/React.createElement("div", {
    style: {
      position: 'relative',
      zIndex: 2
    }
  }, /*#__PURE__*/React.createElement(SectionHeading, {
    eyebrow: "GET IN TOUCH",
    title: /*#__PURE__*/React.createElement(React.Fragment, null, "\u672A\u6765\u3092\u5171\u306B", /*#__PURE__*/React.createElement("br", null), "\u5275\u9020\u3057\u3088\u3046\u3002"),
    size: "contact"
  }, "\u304A\u554F\u3044\u5408\u308F\u305B\u30BB\u30AF\u30B7\u30E7\u30F3\u306E\u5DE6\u30AB\u30E9\u30E0\u30EA\u30FC\u30C9\u6587\u3002\u8A2A\u554F\u8005\u304C\u30D5\u30A9\u30FC\u30E0\u9001\u4FE1\u306B\u8E0F\u307F\u5207\u308B\u305F\u3081\u306E\u52D5\u6A5F\u4ED8\u3051\u3068\u306A\u308B\u30E1\u30C3\u30BB\u30FC\u30B8\u3092\u914D\u7F6E\u3057\u307E\u3059\u3002\u30D3\u30B8\u30E7\u30F3\u3078\u306E\u5171\u611F\u3084\u6B21\u306E\u30B9\u30C6\u30C3\u30D7\u3078\u306E\u671F\u5F85\u611F\u3092\u9AD8\u3081\u308B\u6587\u7AE0\u304C\u52B9\u679C\u7684\u3067\u3059\u3002")), /*#__PURE__*/React.createElement("div", {
    style: {
      position: 'relative',
      zIndex: 2
    }
  }, sent ? /*#__PURE__*/React.createElement("div", {
    style: {
      border: 'var(--border-hairline)',
      background: 'var(--card-bg)',
      padding: '48px 36px',
      textAlign: 'center'
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      width: 'var(--icon-disc)',
      height: 'var(--icon-disc)',
      margin: '0 auto 20px',
      background: 'var(--tint-red-15)',
      borderRadius: 'var(--radius-full)',
      display: 'flex',
      alignItems: 'center',
      justifyContent: 'center',
      color: 'var(--red)',
      fontSize: '1.3rem'
    }
  }, /*#__PURE__*/React.createElement("i", {
    className: "fa-solid fa-paper-plane"
  })), /*#__PURE__*/React.createElement("h3", {
    style: {
      fontFamily: 'var(--font-display)',
      fontSize: 'var(--fs-lg)',
      fontWeight: 700,
      color: '#fff',
      marginBottom: '10px'
    }
  }, "Message Received"), /*#__PURE__*/React.createElement("p", {
    style: {
      fontSize: 'var(--fs-sm-4)',
      color: 'var(--text-muted)',
      lineHeight: 'var(--lh-relaxed)'
    }
  }, "\u304A\u554F\u3044\u5408\u308F\u305B\u3042\u308A\u304C\u3068\u3046\u3054\u3056\u3044\u307E\u3059\u3002\u62C5\u5F53\u8005\u3088\u308A2\u55B6\u696D\u65E5\u4EE5\u5185\u306B\u3054\u9023\u7D61\u3044\u305F\u3057\u307E\u3059\u3002")) : /*#__PURE__*/React.createElement("div", {
    style: {
      display: 'flex',
      flexDirection: 'column',
      gap: '12px'
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      display: 'grid',
      gridTemplateColumns: '1fr 1fr',
      gap: '12px'
    }
  }, /*#__PURE__*/React.createElement(Field, {
    placeholder: "\u304A\u540D\u524D"
  }), /*#__PURE__*/React.createElement(Field, {
    type: "email",
    placeholder: "\u30E1\u30FC\u30EB\u30A2\u30C9\u30EC\u30B9"
  })), /*#__PURE__*/React.createElement(Field, {
    multiline: true,
    placeholder: "\u304A\u554F\u3044\u5408\u308F\u305B\u5185\u5BB9"
  }), /*#__PURE__*/React.createElement(Button, {
    variant: "submit",
    onClick: () => setSent(true)
  }, "Submit the Legacy"))));
}
Object.assign(window, {
  Hero,
  Essence,
  Strengths,
  Numbers,
  Process,
  Faq,
  Contact
});
})(); } catch (e) { __ds_ns.__errors.push({ path: "ui_kits/marketing-site/Sections.jsx", error: String((e && e.message) || e) }); }

__ds_ns.Eyebrow = __ds_scope.Eyebrow;

__ds_ns.Logo = __ds_scope.Logo;

__ds_ns.SectionHeading = __ds_scope.SectionHeading;

__ds_ns.VerticalBadge = __ds_scope.VerticalBadge;

__ds_ns.FaqItem = __ds_scope.FaqItem;

__ds_ns.ProcessStep = __ds_scope.ProcessStep;

__ds_ns.StatItem = __ds_scope.StatItem;

__ds_ns.StrengthCard = __ds_scope.StrengthCard;

__ds_ns.Button = __ds_scope.Button;

__ds_ns.Icon = __ds_scope.Icon;

__ds_ns.Field = __ds_scope.Field;

__ds_ns.NavBar = __ds_scope.NavBar;

__ds_ns.SiteFooter = __ds_scope.SiteFooter;

})();
